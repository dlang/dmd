module ddmd.ctfe.ctfe_bc;

import ddmd.expression;
import ddmd.declaration : FuncDeclaration, VarDeclaration, Declaration,
    SymbolDeclaration, STCref;
import ddmd.dsymbol;
import ddmd.dstruct;
import ddmd.init;
import ddmd.mtype;
import ddmd.statement;
import ddmd.sideeffect;
import ddmd.visitor;
import ddmd.arraytypes : Expressions, VarDeclarations;
/**
 * Written By Stefan Koch in 2016
 */

import std.conv : to;

enum perf = 0;
enum bailoutMessages = 0;
enum printResult = 0;
enum cacheBC = 1;
enum UseLLVMBackend = 0;
enum UsePrinterBackend = 0;
enum UseCBackend = 0;
enum abortOnCritical = 1;

private static void clearArray(T)(auto ref T array, uint count)
{
    foreach(i;0 .. count)
    {
        array[i] = typeof(array[0]).init;
    }
}

version = ctfe_noboundscheck;
enum BCBlockJumpTarget
{
  Begin,
  End,
  Continue,
}

struct BCBlockJump
{
    BCAddr at;
    BCBlockJumpTarget jumpTarget;
}

struct UnresolvedGoto
{
    void* ident;
    BCBlockJump[ubyte.max] jumps;
    uint jumpCount;
}

struct JumpTarget
{
    //    Identifier ident;
    uint scopeId;
}

struct UncompiledFunction
{
    FuncDeclaration fd;
    uint fn;
}

struct SwitchFixupEntry
{
    BCAddr atIp;
    alias atIp this;
    /// 0 means jump after the swich
    /// -1 means jump to the defaultStmt
    /// positve numbers denote which case to jump to
    int fixupFor;
}

struct BoolExprFixupEntry
{
    BCAddr unconditional;
    CndJmpBegin conditional;
    /*
    this(BCAddr unconditional) pure
    {
        this.unconditional = unconditional;
    }
*/
    this(CndJmpBegin conditional) pure
    {
        this.conditional = conditional;
    }
}

struct UnrolledLoopState
{
    BCAddr[255] continueFixups;
    uint continueFixupCount;

    BCAddr[255] breakFixups;
    uint breakFixupCount;
}

struct SwitchState
{
    SwitchFixupEntry[255] switchFixupTable;
    uint switchFixupTableCount;

    BCLabel[255] beginCaseStatements;
    uint beginCaseStatementsCount;
}

struct BlackList
{
    import ddmd.identifier : Identifier;

    bool isInitialized() pure const
    {
        return list[0]!is Identifier.init;
    }

    Identifier[32] list;

    void initialize(string[] blacklistNames)
    {
        if (isInitialized)
            return;

        assert(blacklistNames.length <= list.length);
        foreach (i, const ref name; blacklistNames)
        {
            list[i] = Identifier.idPool(name);
        }
    }

    bool isInBlacklist(Identifier i) pure
    {
        foreach (const ref bi; list)
        {
            if (bi is null)
                return false;
            if (bi is i)
                return true;
        }
        return false;
    }

    void defaultBlackList()
    {
        initialize([
                "modify14304", //because of fail_compilation/fail14304.d; We should not be required to check for this.
        ]);
    }

}

Expression evaluateFunction(FuncDeclaration fd, Expressions* args, Expression thisExp)
{
    Expression[] _args;
    if (thisExp)
    {
        debug (ctfe)
            assert(0, "Implicit State via _this_ is not supported right now");
        return null;
    }

    if (args)
        foreach (a; *args)
        {
            _args ~= a;
        }

    return evaluateFunction(fd, _args ? _args : [], thisExp);
}

import ddmd.ctfe.bc_common;


struct SliceDescriptor
{
    enum LengthOffset = 0;
    enum BaseOffset = 4;
    enum CapcityOffset = 8;
    enum ExtraFlagsOffset = 12;
    enum Size = 16;
}

static if (UseLLVMBackend)
{
    import ddmd.ctfe.bc_llvm_backend;

    alias BCGenT = LLVM_BCGen;
}
else static if (UseCBackend)
{
    import ddmd.ctfe.bc_c_backend;

    alias BCGenT = C_BCGen;
}
else static if (UsePrinterBackend)
{
    import ddmd.ctfe.bc_printer_backend;

    alias BCGenT = Print_BCGen;
}
else
{
    import ddmd.ctfe.bc;

    alias BCGenT = BCGen;
}
__gshared SharedCtfeState!BCGenT _sharedCtfeState;
__gshared SharedCtfeState!BCGenT* sharedCtfeState = &_sharedCtfeState;
__gshared BlackList _blacklist;

ulong evaluateUlong(Expression e)
{
    return e.toUInteger;
}

Expression evaluateFunction(FuncDeclaration fd, Expression[] args, Expression _this = null)
{
    _blacklist.defaultBlackList();
    import std.stdio;

    // writeln("Evaluating function: ", fd.toString);
    import ddmd.identifier;
    import std.datetime : StopWatch;

    static if (perf)
    {
        StopWatch csw;
        StopWatch isw;
        StopWatch hiw;
        StopWatch psw;
        hiw.start();
    }
    _sharedCtfeState.initHeap();
    _sharedCtfeState.clearState();
    static if (perf)
    {
        hiw.stop();
        writeln("Initalizing heap took " ~ hiw.peek.usecs.to!string ~ " usecs");
        isw.start();
    }
    __gshared static bcv = new BCV!BCGenT;

    bcv.clear();
    bcv.Initialize();
    static if (perf)
    {
        isw.stop();
        psw.start();
    }

    // HACK since we don't support dealing with _uncompiled_ functions passed as arguments
    // search through the arguments and if we detect a function compile it
    // The above did not work -- investigate

    foreach(arg;args)
    {
        if (arg.type.ty == Tfunction)
        { //TODO we need to fix this!
            static if (bailoutMessages)
                writeln("top-level function arguments are not supported");
            return null;
        }
        if (arg.type.ty == Tpointer && (cast(TypePointer)arg.type).nextOf.ty == Tfunction)
        {
            static if (bailoutMessages)
                writeln("top-level function ptr arguments are not supported");
            return null;
/* TODO we really need to fix this!
            import ddmd.tokens;
            if (arg.op == TOKsymoff)
            {
                auto se = cast(SymOffExp)arg;
                auto _fd = se.var.isFuncDeclaration;
                if (!_fd) continue;
                bcv.visit(fd);
                bcv.compileUncompiledFunctions();
                bcv.clear();
            }
*/
        }
    }
    bcv.clear();
    //bcv.me = fd;

    static if (perf)
    {
        psw.stop();
        csw.start();
    }

    bcv.visit(fd);

    static if (perf)
    {
        csw.stop;
        writeln("Creating and Initialzing bcGen took ", isw.peek.usecs.to!string, " usecs");
        writeln("Generting bc for ", fd.ident.toString, " took ",
            csw.peek.usecs.to!string, " usecs");
    }

    debug (ctfe)
    {
        import std.stdio;
        import std.algorithm;

        bcv.vars.keys.each!(k => (cast(VarDeclaration) k).print);
        bcv.vars.writeln;

        writeln("stackUsage = ", (bcv.sp - 4).to!string ~ " byte");
        writeln("TemporaryCount = ", (bcv.temporaryCount).to!string);
    }

    if (!bcv.IGaveUp)
    {
        import std.algorithm;
        import std.range;
        import std.datetime : StopWatch;
        import std.stdio;

        BCValue[2] errorValues;
        StopWatch sw;
        sw.start();
        bcv.beginArguments();
        BCValue[] bc_args;
        bc_args.length = args.length;
        bcv.beginArguments();
        foreach (i, arg; args)
        {
            bc_args[i] = bcv.genExpr(arg);
            if (bcv.IGaveUp)
            {
                static if (bailoutMessages)
                    writeln("Ctfe died on argument processing for ", arg ? arg.toString
                    : "Null-Argument");
                return null;
            }

        }
        bcv.endArguments();
        bcv.compileUncompiledFunctions();
        bcv.Finalize();

        static if (UseLLVMBackend)
        {
            bcv.gen.print();

            auto retval = bcv.gen.interpret(bc_args, &_sharedCtfeState.heap);
        }
        else static if (UseCBackend)
        {
            auto retval = BCValue.init;
            writeln(bcv.functionalize);
            return null;
        }
        else static if (UsePrinterBackend)
        {
            auto retval = BCValue.init;
            writeln(bcv.result);
            return null;
        }
        else
        {
            debug (ctfe)
            {
                import std.stdio;

                writeln("I have ", _sharedCtfeState.functionCount, " functions!");
                bcv.gen.byteCodeArray[0 .. bcv.ip].printInstructions.writeln();

            }

            auto retval = interpret_(bcv.byteCodeArray[0 .. bcv.ip], bc_args,
                &_sharedCtfeState.heap, &_sharedCtfeState.functions[0], &bcv.calls[0],
                &errorValues[0], &errorValues[1],
                &_sharedCtfeState.errors[0], _sharedCtfeState.stack[]);
            /*            if (fd.ident == Identifier.idPool("extractAttribFlags"))
            {
                import ddmd.hdrgen;
                import ddmd.root.outbuffer;

                OutBuffer ob;
                HdrGenState hgs;
                scope PrettyPrintVisitor v = new PrettyPrintVisitor(&ob, &hgs);

                fd.accept(v);
                writeln(cast(char[]) ob.data[0 .. ob.size]);
                bcv.byteCodeArray[0 .. bcv.ip].printInstructions.writeln;
            }
*/
        }
        sw.stop();
        import std.stdio;

        auto ft = cast(TypeFunction) fd.type;
        assert(ft.nextOf);

        static if (perf)
            writeln("Executing bc for " ~ fd.ident.toString ~ " took " ~ sw.peek.usecs.to!string ~ " us");
        {
            static if (perf)
            {
                StopWatch esw;
                esw.start();
            }
            if (auto exp = toExpression(retval, ft.nextOf,
                    &_sharedCtfeState.heap, &errorValues, &_sharedCtfeState.errors[0]))
            {
                static if (perf)
                {
                    esw.stop();
                    import ddmd.asttypename;
                    writeln(astTypeName(exp));
                    writeln("Converting to AST Expression took " ~ esw.peek.usecs.to!string ~ "us");
                }
                static if (printResult)
                {
                    writeln("Evaluated function:" ~ fd.toString ~ " => " ~ exp.toString);
                }
                return exp;
            }
            else
            {
                static if (bailoutMessages)
                {
                    writeln("Converting to Expression failed");
                }
                return null;
            }
        }
    }
    else
    {
        bcv.insideFunction = false;
        bcv.Finalize();

        static if (UsePrinterBackend)
        {
            auto retval = BCValue.init;
            writeln(bcv.result);
            return null;
        }
        static if (bailoutMessages)
            writeln("Gaveup!");
        return null;

    }

}
/*
 * params(e) The Expression to test.
 * Retruns 1 if the expression is __ctfe, returns -1 if the expression is !__ctfe, 0 for anything else;
 */
private int is__ctfe(const Expression _e)
{
    import ddmd.tokens : TOK;
    import ddmd.id : Id;

    int retval = 1;
    Expression e = cast(Expression) _e;

switch_head:
    switch (e.op)
    {
    case TOK.TOKvar:
        {
            if ((cast(VarExp) e).var.ident == Id.ctfe)
                return retval;
            else
                goto default;
        }

    case TOK.TOKnot:
        {
            e = (cast(NotExp) e).e1;
            retval = (retval == -1 ? 1 : -1);
            goto switch_head;
        }

    case TOK.TOKidentifier:
        {
            if ((cast(IdentifierExp) e).ident == Id.ctfe)
                return retval;
            goto default;
        }

    default:
        {
            return 0;
        }

    }
}

Expression getBoolExprLhs(Expression be)
{
    import ddmd.tokens;

    if (be.op == TOKandand)
    {
        return (cast(AndAndExp) be).e1;
    }
    if (be.op == TOKoror)
    {
        return (cast(OrOrExp) be).e1;
    }

    return null;
}

Expression getBoolExprRhs(Expression be)
{
    import ddmd.tokens;

    if (be.op == TOKandand)
    {
        return (cast(AndAndExp) be).e2;
    }
    if (be.op == TOKoror)
    {
        return (cast(OrOrExp) be).e2;
    }

    return null;
}

string toString(T)(T value) if (is(T : Statement) || is(T : Declaration)
        || is(T : Expression) || is(T : Dsymbol) || is(T : Type) || is(T : Initializer))
{
    string result;
    import std.string : fromStringz;

    const(char)* cPtr = value ? value.toChars() : T.stringof ~ "(null)";

    static if (is(typeof(T.loc)))
    {
        if (value)
        {
            const(char)* lPtr = value.loc.toChars();
            result = cPtr.fromStringz.idup ~ "\t" ~ lPtr.fromStringz.idup;
        }
        else
        {
            result = T.stringof ~ "(null)";
        }
    }
    else
    {
        result = cPtr.fromStringz.idup;
    }

    return result;
}

struct BCSlice
{
    BCType elementType;
}

struct BCPointer
{
    BCType elementType;
    uint indirectionCount;
}

struct BCArray
{
    BCType elementType;

    uint length;

    const(uint) arraySize() const
    {
        return length * basicTypeSize(elementType);
    }

    const(uint) arraySize(const SharedCtfeState!BCGenT* sharedState) const
    {
        return sharedState.size(elementType) * length;
    }
}

struct BeginStructResult
{
    uint structCount;
    BCStruct* _struct;
    alias _struct this;
}

struct BCStruct
{
    uint memberTypeCount;
    uint size;

    BCType[96] memberTypes;
    bool[96] voidInit;

    void addField(const BCType bct, bool isVoidInit)
    {
        memberTypes[memberTypeCount] = bct;
        voidInit[memberTypeCount++] = isVoidInit;
        size += _sharedCtfeState.size(bct);
    }

    const int offset(const int idx)
    {
        int _offset;
        if (idx == -1)
            return -1;

        debug (ctfe)
            assert(idx <= memberTypeCount);
            else if (idx > memberTypeCount)
                return -1;

        foreach (t; memberTypes[0 .. idx])
        {
            _offset += align4(sharedCtfeState.size(t));
        }

        return _offset;
    }

}

struct SharedCtfeState(BCGenT)
{
    uint _threadLock;
    BCHeap heap;
    long[ushort.max / 4] stack; // a Stack of 64K/4 is the Hard Limit;
    StructDeclaration[ubyte.max * 12] structDeclpointerTypes;
    BCStruct[ubyte.max * 12] structTypes;

    TypeSArray[ubyte.max * 16] sArrayTypePointers;
    BCArray[ubyte.max * 16] arrayTypes;

    TypeDArray[ubyte.max * 8] dArrayTypePointers;
    BCSlice[ubyte.max * 8] sliceTypes;

    TypePointer[ubyte.max * 8] pointerTypePointers;
    BCPointer[ubyte.max * 8] pointerTypes;

    BCTypeVisitor btv = new BCTypeVisitor();


    uint structCount;
    uint arrayCount;
    uint sliceCount;
    uint pointerCount;
    // find a way to live without 102_000
    RetainedError[ubyte.max * 32] errors;
    uint errorCount;

    const(BCType) elementType(const BCType type) pure const
    {
        if (type.type == BCTypeEnum.Slice)
            return type.typeIndex <= sliceCount ? sliceTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.Ptr)
            return type.typeIndex <= pointerCount ? pointerTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.Array)
            return type.typeIndex <= arrayCount ? arrayTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.string8)
            return BCType(BCTypeEnum.c8);
        else
            return BCType.init;
    }

    const(BCType) pointerOf(const BCType type) pure
    {
        foreach (uint i, pt; pointerTypes[0 .. pointerCount])
        {
            if (pt.elementType == type)
            {
                return BCType(BCTypeEnum.Ptr, i + 1);
            }
        }

        pointerTypes[pointerCount++] = BCPointer(type);
        return BCType(BCTypeEnum.Ptr, pointerCount);
    }

    void clearState()
    {
        clearArray(sArrayTypePointers, arrayCount);
        clearArray(arrayTypes, arrayCount);
        clearArray(structDeclpointerTypes, structCount);
        clearArray(structTypes, structCount);
        clearArray(dArrayTypePointers, sliceCount);
        clearArray(sliceTypes, sliceCount);
        clearArray(pointerTypePointers, pointerCount);
        clearArray(pointerTypes, pointerCount);
        clearArray(errors, errorCount);

        static if (is(BCFunction))
            clearArray(functions, functionCount);

        _sharedCtfeState.errorCount = 0;
        _sharedCtfeState.arrayCount = 0;
        _sharedCtfeState.sliceCount = 0;
        _sharedCtfeState.pointerCount = 0;
        _sharedCtfeState.errorCount = 0;

        static if (is(BCFunction))
            _sharedCtfeState.functionCount = 0;

    }


    void initHeap(uint maxHeapSize = 2 ^^ 24)
    {
        import ddmd.root.rmem;

        if (heap.heapMax < maxHeapSize)
        {
            void* mem = allocmemory(maxHeapSize * uint.sizeof);
            heap._heap = (cast(uint*) mem)[0 .. maxHeapSize];
            heap.heapMax = maxHeapSize;
            heap.heapSize = 4;
        }
        else
        {
            import core.stdc.string : memset;

            memset(&heap._heap[0], 0, heap._heap[0].sizeof * heap.heapSize);
            heap.heapSize = 4;
        }
    }

    static if (is(BCFunction))
    {
        static assert(is(typeof(BCFunction.funcDecl) == void*));
        BCFunction[ubyte.max * 64] functions;
        int functionCount = 0;
    }
    else
    {
        pragma(msg, BCGenT, " does not support BCFunctions");
    }

    bool addStructInProgress;

    import ddmd.globals : Loc;

    BCValue addError(Loc loc, string msg, BCValue v1 = BCValue.init, BCValue v2 = BCValue.init)
    {
        errors[errorCount++] = RetainedError(loc, msg, v1, v2);
        auto retval = imm32(errorCount);
        retval.vType = BCValueType.Error;
        return retval;
    }

    int getArrayIndex(TypeSArray tsa)
    {
        foreach (i, sArrayTypePtr; sArrayTypePointers[0 .. arrayCount])
        {
            if (tsa == sArrayTypePtr)
            {
                return cast(uint) i + 1;
            }
        }
        // if we get here the type was not found and has to be registerd.
        auto elemType = btv.toBCType(tsa.nextOf);
        auto arraySize = evaluateUlong(tsa.dim);
        assert(arraySize < uint.max);
        if (arrayCount == arrayTypes.length)
            return 0;
        arrayTypes[arrayCount++] = BCArray(elemType, cast(uint) arraySize);
        return arrayCount;
    }

    int getFunctionIndex(FuncDeclaration fd)
    {
        static if (is(typeof(functions)))
        {
            foreach (i, bcFunc; functions[0 .. functionCount])
            {
                if (bcFunc.funcDecl == cast(void*) fd)
                {
                    return cast(uint) i + 1;
                }
            }
        }
        // if we get here the type was not found and has to be registerd.

        return 0;
    }

    int getStructIndex(StructDeclaration sd)
    {
        if (sd is null)
            return 0;

        foreach (i, structDeclPtr; structDeclpointerTypes[0 .. structCount])
        {
            if (structDeclPtr == sd)
            {
                return cast(uint) i + 1;
            }
        }

        //register structType
        auto oldStructCount = structCount;
        btv.visit(sd);
        assert(oldStructCount < structCount);
        return structCount;
    }

    int getPointerIndex(TypePointer pt)
    {
        if (pt is null)
            return 0;

        foreach (i, pointerTypePtr; pointerTypePointers[0 .. pointerCount])
        {
            if (pointerTypePtr == pt)
            {
                return cast(uint) i + 1;
            }
        }

        //register pointerType
        auto oldPointerCount = pointerCount;
        btv.visit(pt);
        assert(oldPointerCount < pointerCount);
        return pointerCount;
    }

    int getSliceIndex(TypeDArray tda)
    {
        if (!tda)
            return 0;

        foreach (i, slice; dArrayTypePointers[0 .. sliceCount])
        {
            if (slice == tda)
            {
                return cast(uint) i + 1;
            }
        }
        //register structType
        auto elemType = btv.toBCType(tda.nextOf);
        if (sliceTypes.length - 1 > sliceCount)
        {
            dArrayTypePointers[sliceCount] = tda;
            sliceTypes[sliceCount++] = BCSlice(elemType);
            return sliceCount;
        }
        else
        {
            //debug (ctfe)
            assert(0, "SliceTypeArray overflowed");
        }
    }

    //NOTE beginStruct and endStruct are not threadsafe at this point.

    BeginStructResult beginStruct(StructDeclaration sd)
    {
        structDeclpointerTypes[structCount] = sd;
        return BeginStructResult(structCount, &structTypes[structCount++]);
    }

    const(BCType) endStruct(BeginStructResult* s)
    {
        return BCType(BCTypeEnum.Struct, s.structCount);
    }
    /*
    string getTypeString(BCType type)
    {

    }
    */
    const(uint) size(const BCType type) const
    {
        static __gshared sizeRecursionCount = 1;
        sizeRecursionCount++;
        import std.stdio;

        if (sizeRecursionCount > 3000)
        {
            writeln("Calling Size for (", type.type.to!string, ", ",
                type.typeIndex.to!string, ")");
            //writeln(getTypeString(bct));
            return 0;
        }

        scope (exit)
        {
            sizeRecursionCount--;
        }
        if (isBasicBCType(type))
        {
            return basicTypeSize(type);
        }

        switch (type.type)
        {
        case BCTypeEnum.Struct:
            {
                uint _size;
                if (type.typeIndex <= structCount)
                {
                    // the if above shoud really be an assert
                    // I have no idea why this even happens
                    return 0;
                }
                BCStruct _struct = structTypes[type.typeIndex - 1];

                foreach (i, memberType; _struct.memberTypes[0 .. _struct.memberTypeCount])
                {
                    if (memberType == type) // bail out on recursion.
                        return 0;

                    _size += align4(
                        isBasicBCType(memberType) ? basicTypeSize(memberType) : this.size(
                        memberType));
                }

                return _size;

            }

        case BCTypeEnum.Array:
            {
                if(type.typeIndex > arrayCount)
                {
                    // the if above shoud really be an assert
                    // I have no idea why this even happens
                    return 0;
                }
                BCArray _array = arrayTypes[type.typeIndex - 1];
                debug (ctfe)
                {
                    import std.stdio;

                    writeln("ArrayElementSize :", size(_array.elementType));
                }
                return size(_array.elementType) * _array.length;
            }
        case BCTypeEnum.Slice:
            {
                return SliceDescriptor.Size;
            }
        case BCTypeEnum.Ptr:
            {
                return 4; // 4 for pointer;
            }
        default:
            {
                debug (ctfe)
                    assert(0, "cannot get size for BCType." ~ to!string(type.type));
                return 0;
            }

        }
    }
}

struct RetainedError // Name is still undecided
{
    import ddmd.tokens : Loc;

    Loc loc;
    string msg;
    BCValue v1;
    BCValue v2;
}

Expression toExpression(const BCValue value, Type expressionType,
    const BCHeap* heapPtr = &_sharedCtfeState.heap,
    const BCValue[2]* errorValues = null, const RetainedError* errors = null)
{
    import ddmd.parse : Loc;
    static if (bailoutMessages)
    {
        import std.stdio;
        writeln("Calling toExpression with Type: ", expressionType.toString);
    }
    Expression result;
    if (value.vType == BCValueType.Unknown)
    {
        debug (ctfe)
        {
            assert(0, "return value was not set");
        }

        return null;
    }

    if (value.vType == BCValueType.Bailout)
    {
        if (value.imm32 == 2000)
        {
            // 2000 means we hit the recursion-limit;
            return null;
        }

        debug (ctfe)
        {
            assert(0, "Interpreter had to bailout");
        }
        import std.stdio;
        static if (bailoutMessages)
        {
            writeln("We just bailed out of the interpreter ... this is bad, VERY VERY VERY bad");
            writeln("It means we have missed to fixup jumps or did not emit a return or something along those lines");
        }
        static if (abortOnCritical)
            assert(0);
        else
            return null;
    }

    if (value.vType == BCValueType.Error)
    {
        assert(value.type == i32Type);
        assert(value.imm32, "Errors are 1 based indexes");
        import ddmd.ctfeexpr : CTFEExp;

        auto err = _sharedCtfeState.errors[value.imm32 - 1];
        import ddmd.errors;

        uint e1;
        uint e2;

        if (errorValues)
        {
            e1 = (*errorValues)[0].imm32;
            e2 = (*errorValues)[1].imm32;
        }
        else
        {
            // HACK
            // Bailing out if we have no error values.
            // this is not good!
            // it indicates that we miscompile something!
            return null;
        }
        if (err.msg.ptr)
            error(err.loc, err.msg.ptr, e1, e2);

        return CTFEExp.cantexp;
    }

    Expression createArray(BCValue arr, Type elmType)
    {
        ArrayLiteralExp arrayResult;
        auto baseType = _sharedCtfeState.btv.toBCType(elmType);
        auto elmLength = _sharedCtfeState.size(baseType);
        auto arrayLength = heapPtr._heap[arr.heapAddr.addr + SliceDescriptor.LengthOffset];
        auto arrayBase = heapPtr._heap[arr.heapAddr.addr + SliceDescriptor.BaseOffset];
        debug (ctfe)
        {
            import std.stdio;

            writeln("value ", value.toString);
        }
        debug (ctfe)
        {
            import std.stdio;

            foreach (idx; 0 .. heapPtr.heapSize)
            {
                // writefln("%d %x", idx, heapPtr._heap[idx]);
            }
        }

        Expressions* elmExprs = new Expressions();

        uint offset = 0;
        debug (ctfe)
        {
            import std.stdio;

            writeln("building Array of Length ", arrayLength);
        }
        /* import std.stdio;
            writeln("HeapAddr: ", value.heapAddr.addr);
            writeln((cast(char*)(heapPtr._heap.ptr + value.heapAddr.addr + 1))[0 .. 64]);
            */

        foreach (idx; 0 .. arrayLength)
        {
            /*    if (elmLength == 1)
                {
                    elmExprs.insert(idx,
                        toExpression(imm32((heapPtr._heap[value.heapAddr.addr + offset] >> ((idx-1 % 4) * 8)) & 0xFF),
                        tda.nextOf)
                    );
                    offset += !(idx % 4);
                }
                else */
            {
                elmExprs.insert(idx,
                    toExpression(imm32(*(heapPtr._heap.ptr + arrayBase + offset)),
                        elmType));
                offset += elmLength;
            }

        }

        arrayResult = new ArrayLiteralExp(Loc(), elmExprs);
        arrayResult.ownedByCtfe = OWNEDctfe;

        return arrayResult;
    }

    if (expressionType.isString)
    {
        import ddmd.lexer : Loc;



        auto length = heapPtr._heap.ptr[value.heapAddr + SliceDescriptor.LengthOffset];
        auto base = heapPtr._heap.ptr[value.heapAddr + SliceDescriptor.BaseOffset];
        uint sz = cast (uint) expressionType.nextOf().size;
        if (sz != 1)
        {
            static if (bailoutMessages)
            {
                import std.stdio;
                writefln("We canot deal with stringElementSize: %d", sz);
            }
            return null;
        }
        auto offset = cast(uint)base;
        import ddmd.root.rmem : allocmemory;

        auto resultString = cast(char*)allocmemory(length * sz + sz);

        assert(sz == 1, "missing UTF-16/32 support");
        foreach (i; 0 .. length)
            resultString[i] = cast(char) heapPtr._heap[offset + i];
        resultString[length] = '\0';

        result = new StringExp(Loc(), cast(void*)resultString, length);
        (cast(StringExp) result).ownedByCtfe = OWNEDctfe;
    }
    else
        switch (expressionType.ty)
    {
    case Tstruct:
        {
            auto sd = (cast(TypeStruct) expressionType).sym;
            auto si = _sharedCtfeState.getStructIndex(sd);
            assert(si);
            BCStruct _struct = _sharedCtfeState .structTypes[si - 1];
            Expressions* elmExprs = new Expressions();
            uint offset = 0;
            foreach (idx, member; _struct.memberTypes[0 .. _struct.memberTypeCount])
            {
                auto type = sd.fields[idx].type;

                Expression elm = toExpression(
                    imm32(*(heapPtr._heap.ptr + value.heapAddr.addr + offset)), type);
                if (!elm)
                {
                    static if (bailoutMessages)
                    {
                        import std.stdio;
                        writeln("We could not covert the sub-expression of a struct of type ", type.toString);
                    }
                    return null;
                }
                elmExprs.insert(idx, elm);
                offset += align4(_sharedCtfeState.size(member));
            }
            result = new StructLiteralExp(Loc(), sd, elmExprs);
            (cast(StructLiteralExp) result).ownedByCtfe = OWNEDctfe;
        }
        break;
    case Tsarray:
        {
            auto tsa = cast(TypeSArray) expressionType;
            assert(heapPtr._heap[value.heapAddr.addr + SliceDescriptor.LengthOffset] == evaluateUlong(tsa.dim),
                "static arrayLength mismatch: " ~ to!string(heapPtr._heap[value.heapAddr.addr + SliceDescriptor.LengthOffset]) ~ " != " ~ to!string(
                    evaluateUlong(tsa.dim)));
            result = createArray(value, tsa.nextOf);
        } break;
    case Tarray:
        {
            auto tda = cast(TypeDArray) expressionType;
            result = createArray(value, tda.nextOf);
        }
        break;
    case Tbool:
        {
            //assert(value.imm32 == 0 || value.imm32 == 1, "Not a valid bool");
            result = new IntegerExp(value.imm32);
        }
        break;
    case Tint32, Tuns32, Tint16, Tuns16, Tint8, Tuns8:
        {
            result = new IntegerExp(value.imm32);
        }
        break;
    case Tint64, Tuns64:
        {
            result = new IntegerExp(value.imm64);
        }
        break;
    case Tpointer:
        {
            //FIXME this will _probably_ only work for basic types with one level of indirection (eg, int*, uint*)
            if (expressionType.nextOf.ty == Tvoid)
            {
                static if (bailoutMessages)
                {
                    writeln("trying to build void ptr ... we cannot really do this");
                }
                return null;
            }
            result = new AddrExp(Loc.init,
                toExpression(imm32(*(heapPtr._heap.ptr + value.imm32)), expressionType.nextOf));
        }
        break;
    default:
        {
            debug (ctfe)
                assert(0, "Cannot convert to " ~ expressionType.toString!Type ~ " yet.");
        }
    }
    if (result)
        result.type = expressionType;

    static if (bailoutMessages)
    {
        if (!result)
        {
            import std.stdio;
            writeln("could not create expression");
        }
    }

    return result;
}

extern (C++) final class BCTypeVisitor : Visitor
{
    alias visit = super.visit;
    Type topLevelAggregate;
    uint prevAggregateTypeCount;
    Type[32] prevAggregateTypes;

    const(BCType) toBCType(Type t, Type tla = null) /*pure*/
    {
        assert(t !is null);
        switch (t.ty)
        {
        case ENUMTY.Tbool:
            //return BCType(BCTypeEnum.i1);
            return BCType(BCTypeEnum.i32);
        case ENUMTY.Tchar:
            return BCType(BCTypeEnum.c8);
        case ENUMTY.Twchar:
            //return BCType(BCTypeEnum.c16);
        case ENUMTY.Tdchar:
            //return BCType(BCTypeEnum.c32);
            return BCType(BCTypeEnum.Char);
        case ENUMTY.Tuns8:
            //return BCType(BCTypeEnum.u8);
        case ENUMTY.Tint8:
            //return BCType(BCTypeEnum.i8);
        case ENUMTY.Tuns16:
            //return BCType(BCTypeEnum.u16);
        case ENUMTY.Tint16:
            //return BCType(BCTypeEnum.i16);
        case ENUMTY.Tuns32:
            //return BCType(BCTypeEnum.u32);
        case ENUMTY.Tint32:
            return BCType(BCTypeEnum.i32);
        case ENUMTY.Tuns64:
            //return BCType(BCTypeEnum.u64);
        case ENUMTY.Tint64:
            return BCType(BCTypeEnum.i64);
        case ENUMTY.Tfloat32:
            //return BCType(BCTypeEnum.f32);
        case ENUMTY.Tfloat64:
            //return BCType(BCTypeEnum.f64);
        case ENUMTY.Tfloat80:
            //return BCType(BCTypeEnum.f64);
        case ENUMTY.Timaginary32:
        case ENUMTY.Timaginary64:
        case ENUMTY.Timaginary80:
        case ENUMTY.Tcomplex32:
        case ENUMTY.Tcomplex64:
        case ENUMTY.Tcomplex80:
            return BCType.init;
        case ENUMTY.Tvoid:
            return BCType(BCTypeEnum.Void);
        default:
            break;
        }
        // If we get here it's not a basic type;
        assert(!t.isTypeBasic(), "Is a basicType: " ~ (cast(ENUMTY) t.ty).to!string());
        if (t.isString)
        {
            auto sz = t.nextOf().size;
            switch(sz)
            {
                case 1 : return BCType(BCTypeEnum.string8);
                case 2 : return BCType(BCTypeEnum.string16);
                case 4 : return BCType(BCTypeEnum.string32);
                default :
                {
                    static if (bailoutMessages)
                    {
                        import std.stdio;
                        writefln("String of invalid elmementSize: %d", sz);
                    }
                    return BCType.init;
                }
            }
        }
        else if (t.ty == Tstruct)
        {
            if (!topLevelAggregate)
            {
                topLevelAggregate = t;
            }
            else if (topLevelAggregate == t)
            {
                // struct S { S s } is illegal!
                assert(0, "This should never happen");
            }
            auto sd = (cast(TypeStruct) t).sym;
            auto result = BCType(BCTypeEnum.Struct, _sharedCtfeState.getStructIndex(sd));
            topLevelAggregate = typeof(topLevelAggregate).init;
            return result;
        }
        else if (t.ty == Tarray)
        {
            auto tarr = (cast(TypeDArray) t);
            return BCType(BCTypeEnum.Slice, _sharedCtfeState.getSliceIndex(tarr));
        }
        else if (t.ty == Tenum)
        {
            return toBCType(t.toBasetype);
        }
        else if (t.ty == Tsarray)
        {
            auto tsa = cast(TypeSArray) t;
            return BCType(BCTypeEnum.Array, _sharedCtfeState.getArrayIndex(tsa));
        }
        else if (t.ty == Tpointer)
        {
            //if (t.nextOf.ty == Tint32 || t.nextOf.ty == Tuns32)
            //    return BCType(BCTypeEnum.i32Ptr);
            //else if (auto pi =_sharedCtfeState.getPointerIndex(cast(TypePointer)t))
            //{
            //return BCType(BCTypeEnum.Ptr, pi);
            //}
            //else
            {
                uint indirectionCount = 1;
                Type baseType = t.nextOf;
                while (baseType.ty == Tpointer)
                {
                    indirectionCount++;
                    baseType = baseType.nextOf;
                }
                _sharedCtfeState.pointerTypePointers[_sharedCtfeState.pointerCount] = cast(
                    TypePointer) t;
                _sharedCtfeState.pointerTypes[_sharedCtfeState.pointerCount++] = BCPointer(
                    baseType != topLevelAggregate ? toBCType(baseType) : BCType(BCTypeEnum.Struct,
                    _sharedCtfeState.structCount + 1), indirectionCount);
                return BCType(BCTypeEnum.Ptr, _sharedCtfeState.pointerCount);
            }
        }
        else if (t.ty == Tfunction)
        {
            return BCType(BCTypeEnum.Function);
        }

        debug (ctfe)
            assert(0, "NBT Type unsupported " ~ (cast(Type)(t)).toString);

        return BCType.init;
    }

    override void visit(StructDeclaration sd)
    {
        auto st = sharedCtfeState.beginStruct(sd);

        foreach (sMember; sd.fields)
        {
            if (sMember.type.ty == Tstruct && (cast(TypeStruct) sMember.type).sym == sd)
                assert(0, "recursive struct definition this should never happen");

            auto bcType = toBCType(sMember.type);
            st.addField(bcType, sMember._init ? !!sMember._init.isVoidInitializer() : false);
        }

        _sharedCtfeState.endStruct(&st);

    }

}

struct BCScope
{

    //    Identifier[64] identifiers;
    BCBlock[64] blocks;
}

debug = nullPtrCheck;
//debug = andand;
extern (C++) final class BCV(BCGenT) : Visitor
{
    uint unresolvedGotoCount;
    uint breakFixupCount;
    uint continueFixupCount;
    uint fixupTableCount;
    uint uncompiledFunctionCount;
    uint scopeCount;
    uint processedArgs;
    uint switchStateCount;
    uint currentFunction;

    BCGenT gen;
    alias gen this;

    // for now!

    BCValue[] arguments;
    BCType[] parameterTypes;

    //    typeof(this)* parent;

    bool processingArguments;
    bool insideArgumentProcessing;
    bool processingParameters;
    bool insideArrayLiteralExp;

    bool IGaveUp;

    void clear()
    {
        unresolvedGotoCount = 0;
        breakFixupCount = 0;
        continueFixupCount = 0;
        scopeCount = 0;
        fixupTableCount = 0;
        processedArgs = 0;
        switchStateCount = 0;
        currentFunction = 0;

        arguments = [];
        parameterTypes = [];

        processingArguments = false;
        insideArgumentProcessing = false;
        processingParameters = false;
        insideArrayLiteralExp = false;
        IGaveUp = false;
        discardValue = false;
        ignoreVoid = false;
        noRetval = false;

        lastConstVd = lastConstVd.init;
        unrolledLoopState = null;
        switchFixup = null;
        switchState = null;
        me = null;
        lastContinue = typeof(lastContinue).init;

        currentIndexed = BCValue.init;
        retval = BCValue.init;
        assignTo = BCValue.init;

        labeledBlocks.destroy();
        vars.destroy();
    }

    UnrolledLoopState* unrolledLoopState;
    SwitchState* switchState;
    SwitchFixupEntry* switchFixup;

    FuncDeclaration me;
    bool inReturnStatement;
    Expression lastExpr;

    UnresolvedGoto[ubyte.max] unresolvedGotos = void;
    BCAddr[ubyte.max] breakFixups = void;
    BCAddr[ubyte.max] continueFixups = void;
    BCScope[16] scopes = void;
    BoolExprFixupEntry[ubyte.max] fixupTable = void;
    UncompiledFunction[ubyte.max * 8] uncompiledFunctions = void;
    SwitchState[16] switchStates = void;

    alias visit = super.visit;

    const(BCType) toBCType(Type t)
    {
        auto bct = _sharedCtfeState.btv.toBCType(t);
        if (bct != BCType.init)
        {
            return bct;
        }
        else
        {
            bailout("Type unsupported " ~ (cast(Type)(t)).toString());
            return BCType.init;
        }
    }

    import ddmd.tokens;

    BCBlock[void* ] labeledBlocks;
    bool ignoreVoid;
    bool noRetval;
    BCValue[void* ] vars;
    BCValue _this;
    VarDeclaration lastConstVd;

    typeof(gen.genLabel()) lastContinue;
    BCValue currentIndexed;

    BCValue retval;
    BCValue assignTo;

    bool discardValue = false;

    debug (nullPtrCheck)
    {
        import ddmd.lexer : Loc;

        void Load32(BCValue _to, BCValue from, size_t line = __LINE__)
        {
            Assert(from.i32, _sharedCtfeState.addError(Loc.init,
                    "Load Source may not be null - target: " ~ to!string(_to.stackAddr) ~ " inLine: " ~ to!string(line)));
            gen.Load32(_to, from);
        }

        void Store32(BCValue _to, BCValue value, size_t line = __LINE__)
        {
            Assert(_to.i32, _sharedCtfeState.addError(Loc.init,
                    "Store Destination may not be null - from: " ~ to!string(value.stackAddr) ~ " inLine: " ~ to!string(line)));
            gen.Store32(_to, value);
        }

    }

    static if (is(gen.Supports64BitCells) && gen.Supports64BitCalls)
    {
        void Load64(BCValue _to, BCValue from)
        {
            Load32(_to.i32, from); // load lower 32bit
            auto upperAddr = genTemporary(i32Type);
            auto upperVal = genTemporary(i32Type);
            Add3(upperAddr, from, imm32(4));
            Load32(upperVal, upperAddr);
            SetHigh(_to, upperVal);
        }

        void Store64(BCValue _to, BCValue from)
        {
            Store32(_to, from.i32); // load lower 32bit
            auto upperAddr = genTemporary(i32Type);
            auto upperVal = genTemporary(i32Type);
            Add3(upperAddr, _to, imm32(4));
            SetHigh(from, upperVal);
            Store32(upperAddr, upperVal);
        }
    }
    else
    {
        void Load64(BCValue _to, BCValue from)
        {
            bailout("Load64 unsupported by " ~ BCGenT.stringof);
        }

        void Store64(BCValue _to, BCValue from)
        {
            bailout("Store64 unsupported by " ~ BCGenT.stringof);
        }
    }

    void doFixup(uint oldFixupTableCount, BCLabel* ifTrue, BCLabel* ifFalse)
    {
        foreach (fixup; fixupTable[oldFixupTableCount .. fixupTableCount])
        {
            if (fixup.conditional.ifTrue)
            {
                endCndJmp(fixup.conditional, ifTrue ? *ifTrue : genLabel());
            }
            else
            {
                endCndJmp(fixup.conditional, ifFalse ? *ifFalse : genLabel());
            }

            --fixupTableCount;
        }
    }

    extern (D) void bailout(bool value, const(char)[] message, size_t line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {
        if (value)
        {
            bailout(message, line, pfn);
        }
    }

    extern (D) void bailout(const(char)[] message, size_t line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {
        IGaveUp = true;
        const fnIdx = _sharedCtfeState.getFunctionIndex(me);

        enum headLn = 58;
        if (pfn.length > headLn)
        {
            import std.string : indexOf;
            auto offset = 50;
            auto begin = pfn[offset .. $].indexOf('(') + offset + 1;
            auto end = pfn[begin .. $].indexOf(' ') + begin;
            pfn = pfn[begin .. end];
        }

        if (fnIdx)
            static if (is(BCFunction))
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(null);
            }
        debug (ctfe)
        {
            assert(0, "bailout on " ~ pfn ~ " (" ~ to!string(line) ~ "): " ~ message);
        }
        else
        {
            import std.stdio;
            static if (bailoutMessages)
                writefln("bailout on %s (%d): %s", pfn, line, message);
        }
    }

    void StringEq(BCValue retval, BCValue lhs, BCValue rhs)
    {
        static if (is(typeof(StrEq3) == function)
                && is(typeof(StrEq3(BCValue.init, BCValue.init, BCValue.init)) == void))
        {
            StrEq3(retval, lhs, rhs);
        }

        else
        {
            import ddmd.ctfe.bc_macro : StringEq3Macro;

            bool wasInit;
            if (!retval)
            {
                wasInit = true;
                retval = genTemporary(i32Type);
            }
            StringEq3Macro(&gen, retval, lhs, rhs);
            if (wasInit)
            {
                Eq3(BCValue.init, retval, imm32(1));
            }
        }
    }

public:

/*    this(FuncDeclaration fd, Expression _this)
    {
        me = fd;
        if (_this)
            this._this = _this;
    }
*/
    void beginParameters()
    {
        processingParameters = true;
    }

    void endParameters()
    {
        processingParameters = false;
        // add this Pointer as last parameter
        assert(me);
        if (me.vthis)
        {
            _this = genParameter(toBCType(me.vthis.type));
            setVariable(me.vthis, _this);
        }
    }

    void beginArguments()
    {
        processingArguments = true;
        insideArgumentProcessing = true;
    }

    void endArguments()
    {
        processedArgs = 0;
        processingArguments = false;
        insideArgumentProcessing = false;
    }

    BCValue getVariable(VarDeclaration vd)
    {
        import ddmd.declaration : STCmanifest, STCstatic, STCimmutable;
        if (vd.storage_class & STCref)
        {
            if (toBCType(vd.type) != i32Type)
            {
                bailout("We can only handle 32bit refs for now");
                return BCValue.init;
            }
        }

        if (vd.storage_class & STCstatic && !(vd.storage_class & STCimmutable))
        {
            bailout("cannot handle static variables");
            return BCValue.init;
        }

        if (auto value = (cast(void*) vd) in vars)
        {
            if (vd.storage_class & STCref && !value.heapRef)
            {
             //   assert(0, "We got a ref and the heapRef is not set this is BAD!");
            }
            return *value;
        }
        else if ((vd.isDataseg() || vd.storage_class & STCmanifest) && !vd.isCTFE() && vd._init)
        {
            if (vd == lastConstVd)
                bailout("circular initialisation apperantly");

            lastConstVd = vd;
            if (auto ci = vd.getConstInitializer())
            {
                return genExpr(ci);
            }

            return BCValue.init;
        }
        else
        {
            return BCValue.init;
        }
    }
    /*
    BCValue pushOntoHeap(BCValue v)
    {
        assert(isBasicBCType(toBCType(v)), "For now only basicBCTypes are supported");

    }
*/
    BCValue genExpr(Expression expr)
    {

        debug (ctfe)
        {
            import std.stdio;
        }
        auto oldRetval = retval;

        if (processingArguments)
        {
            debug (ctfe)
            {
                import std.stdio;

                //    writeln("Arguments ", arguments);
            }
            if (processedArgs != arguments.length)
            {

                processingArguments = false;
                assert(processedArgs < arguments.length);
                assignTo = arguments[processedArgs++];
                assert(expr);
                expr.accept(this);
                processingArguments = true;

            }
            else
            {
                bailout("passed too many arguments");
            }
        }
        else
        {

            if (expr)
                expr.accept(this);
        }
        debug (ctfe)
        {
            import std.stdio;
            writeln("expr: ", expr.toString, " == ", retval);
        }
        //        assert(!discardValue || retval.vType != BCValueType.Unknown);
        BCValue ret = retval;
        retval = oldRetval;

        //        if (processingArguments) {
        //            arguments ~= retval;
        //            assert(arguments.length <= parameterTypes.length, "passed to many arguments");
        //        }

        return ret;
    }

    static if (is(BCFunction) && is(typeof(_sharedCtfeState.functionCount)))
    {
        void addUncompiledFunction(FuncDeclaration fd, int* fnIdxP)
        {
            assert(*fnIdxP == 0, "addUncompiledFunction has to called with *fnIdxP == 0");
            if (uncompiledFunctionCount >= uncompiledFunctions.length - 64)
            {
                bailout("UncompiledFunctions overflowed");
                return ;
            }

            if (!fd)
                return ;

            if (!fd.functionSemantic3())
            {
                bailout("could not interpret (did not pass functionSemantic3())" ~ fd.getIdent.toString);
                return ;
            }

            if (fd.hasNestedFrameRefs /*|| fd.isNested*/)
            {
                bailout("cannot deal with closures of any kind: " ~ fd.toString);
                return ;
            }

            if (fd.fbody)
            {
                const fnIdx = ++_sharedCtfeState.functionCount;
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd);
                uncompiledFunctions[uncompiledFunctionCount++] = UncompiledFunction(fd, fnIdx);
                *fnIdxP = fnIdx;
            }
            else
            {
                bailout("Null-Body: probably builtin: " ~ fd.toString);
            }
        }
    }
    else
    {
        void addUncompiledFunction(FuncDeclaration fd, int *fnIdxP)
        {
            assert(0, "We don't support Functions!\nHow do you expect me to add a function ?");
        }
    }

    void compileUncompiledFunctions()
    {
        uint lastUncompiledFunction;

    LuncompiledFunctions :
        foreach (uf; uncompiledFunctions[lastUncompiledFunction .. uncompiledFunctionCount])
        {
            if (_blacklist.isInBlacklist(uf.fd.ident))
            {
                bailout("Bailout on blacklisted");
                return;
            }

            //assert(!me, "We are not clean!");
            me = uf.fd;
            beginParameters();
            auto parameters = uf.fd.parameters;
            if (parameters)
                foreach (i, p; *parameters)
            {
                debug (ctfe)
                {
                    import std.stdio;

                    writeln("uc parameter [", i, "] : ", p.toString);
                }
                p.accept(this);
            }
            endParameters();
            if (parameters)
                linkRefsCallee(parameters);

            auto fnIdx = uf.fn;
            beginFunction(fnIdx - 1, cast(void*)uf.fd);
            uf.fd.fbody.accept(this);
            auto osp = sp;

            if (uf.fd.type.nextOf.ty == Tvoid)
            {
                // insert a dummy return after void functions because they can omit a returnStatement
                Ret(bcNull);
            }
            endFunction();
            lastUncompiledFunction++;
            if (IGaveUp)
            {
                bailout("A called function bailedout: " ~ uf.fd.toString);
                return ;
            }

            static if (is(BCGen))
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) uf.fd,
                    fnIdx, BCFunctionTypeEnum.Bytecode,
                    cast(ushort) (parameters ? parameters.dim : 0), osp.addr, //FIXME IMPORTANT PERFORMANCE!!!
                    // get rid of dup!
                    byteCodeArray[0 .. ip].idup);
            }
            else
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) uf.fd);
            }
            clear();

        }

        if (uncompiledFunctionCount > lastUncompiledFunction)
            goto LuncompiledFunctions;

        clearArray(uncompiledFunctions, uncompiledFunctionCount);
        // not sure if the above clearArray does anything
        uncompiledFunctionCount = 0;
    }

    override void visit(FuncDeclaration fd)
    {
        import ddmd.identifier;

        //HACK this filters out functions which I know produce incorrect results
        //this is only so I can see where else are problems.
        assert(!me || me == fd);
        me = fd;
        if (_blacklist.isInBlacklist(fd.ident))
        {
            bailout("Bailout on blacklisted");
            return;
        }
        import std.stdio;
        if (insideFunction)
        {
/*
            auto fnIdx = _sharedCtfeState.getFunctionIndex(fd);
            addUncompiledFunction(fd, &fnIdx);
            return ;
*/
        }

        //writeln("going to eval: ", fd.toString);
        if (auto fbody = fd.fbody.isCompoundStatement)
        {
            beginParameters();
            if (fd.parameters)
                foreach (i, p; *(fd.parameters))
                {
                    debug (ctfe)
                    {
                        import std.stdio;

                        writeln("parameter [", i, "] : ", p.toString);
                    }
                    p.accept(this);
                }
            endParameters();
            debug (ctfe)
            {
                import std.stdio;

                writeln("ParameterType : ", parameterTypes);
            }
            import std.stdio;
            assert(me, "We did not set ourselfs");
            auto fnIdx = _sharedCtfeState.getFunctionIndex(me);
            static if (is(typeof(_sharedCtfeState.functionCount)) && cacheBC)
            {
                fnIdx = fnIdx ? fnIdx : ++_sharedCtfeState.functionCount;
            }
            else
            {
                fnIdx = 1;
            }
            beginFunction(fnIdx - 1, cast(void*)fd);
            visit(fbody);
            if (fd.type.nextOf.ty == Tvoid)
            {
                // insert a dummy return after void functions because they can omit a returnStatement
                Ret(bcNull);
            }
            auto osp2 = sp.addr;
            endFunction();
            if (IGaveUp)
            {
                debug (ctfe)
                {
                    static if (UsePrinterBackend)
                        writeln(result);
                    else static if (UseCBackend)
                        writeln(code);
                    else static if (UseLLVMBackend)
                    {
                    }
                    else
                        writeln(printInstructions(byteCodeArray[0 .. ip]));
                    static if (bailoutMessages)
                        writeln("Gave up!");
                }
                return;
            }

            static if (is(typeof(_sharedCtfeState.functions)))
            {
                //FIXME IMPORTANT PERFORMANCE!!!
                // get rid of dup!

                auto myPTypes = parameterTypes.dup;
                auto myArgs = arguments.dup;
static if (is(BCGen))
{
                auto myCode = byteCodeArray[0 .. ip].idup;
                auto myIp = ip;
}
                //FIXME IMPORTANT PERFORMANCE!!!
                // get rid of dup!

                debug (ctfe)
                {
                    writeln("FnCnt: ", _sharedCtfeState.functionCount);
                }
                static if (cacheBC)
                {
                    static if (is(BCGen))
                    {
                        _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd,
                            fnIdx, BCFunctionTypeEnum.Bytecode,
                            cast(ushort) parameterTypes.length, osp2,
                            myCode);
                        clear();
                    }
                    else
                    {
                        _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd);
                    }

                    compileUncompiledFunctions();

                    parameterTypes = myPTypes;
                    arguments = myArgs;
static if (is(BCGen))
{
                    //FIXME PERFORMACE get RID of this loop!
                    foreach(i,c;myCode)
                    {
                        byteCodeArray[i] = c;
                    }
                    ip = myIp;
}
                }
                else
                {
                    //static assert(0, "No functions for old man");
                }
            }
        }
    }

    override void visit(BinExp e)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("Called visit(BinExp) %s ... \n\tdiscardReturnValue %d",
                e.toString, discardValue);
            writefln("(BinExp).Op: %s", e.op.to!string);

        }
        bool wasAssignTo;
        if (assignTo)
        {
            wasAssignTo = true;
            retval = assignTo;
            assignTo = BCValue.init;
        }
        else
        {
            if (!noRetval)
                retval = genTemporary(toBCType(e.type));
        }
        switch (e.op)
        {

        case TOK.TOKplusplus:
            {
                const oldDiscardValue = discardValue;
                discardValue = false;
                auto expr = genExpr(e.e1);
                if (!canWorkWithType(expr.type) || !canWorkWithType(retval.type))
                {
                    bailout("++ only i32 is supported not " ~ to!string(expr.type.type));
                    return;
                }
                assert(expr.vType != BCValueType.Immediate,
                    "++ does not make sense as on an Immediate Value");

                discardValue = oldDiscardValue;
                Set(retval, expr);

                Add3(expr, expr, imm32(1));

            }
            break;
        case TOK.TOKminusminus:
            {
                const oldDiscardValue = discardValue;
                discardValue = false;
                auto expr = genExpr(e.e1);
                if (!canWorkWithType(expr.type) || !canWorkWithType(retval.type))
                {
                    bailout("-- only i32 is supported not " ~ to!string(expr.type.type));
                    return;
                }
                assert(expr.vType != BCValueType.Immediate,
                    "-- does not make sense as on an Immediate Value");

                discardValue = oldDiscardValue;
                Set(retval, expr);

                Sub3(expr, expr, imm32(1));
            }
            break;
        case TOK.TOKequal, TOK.TOKnotequal:
            {

                if (e.e1.type.isString && e.e2.type.isString)
                {
                    auto lhs = genExpr(e.e1);
                    auto rhs = genExpr(e.e2);
                    if (!lhs || !rhs)
                    {
                        bailout("could not gen lhs or rhs for " ~ e.toString);
                        return ;
                    }
                    StringEq(retval, lhs, rhs);
                }
                else if (canHandleBinExpTypes(toBCType(e.e1.type), toBCType(e.e2.type)))
                {
                    goto case TOK.TOKadd;
                }
            }
            break;
        case TOK.TOKquestion:
            {
                auto ce = cast(CondExp) e;
                auto cond = genExpr(ce.econd);
                debug (ctfe)
                    assert(cond);
                    else if (!cond)
                    {
                        bailout("Conditional in ? : could not be evaluated");
                        return;
                    }

                auto cj = beginCndJmp(cond ? cond.i32 : cond, false);
                auto lhsEval = genLabel();
                auto lhs = genExpr(e.e1);
                // FIXME this is a hack we should not call Set this way
                Set(retval.i32, lhs.i32);
                auto toend = beginJmp();
                auto rhsEval = genLabel();
                auto rhs = genExpr(e.e2);
                // FIXME this is a hack we should not call Set this way
                Set(retval.i32, rhs.i32);
                endCndJmp(cj, rhsEval);
                endJmp(toend, genLabel());
            }
            break;
        case TOK.TOKcat:
            {
                bailout("We don't handle ~ right now");
                auto lhs = genExpr(e.e1);
                auto rhs = genExpr(e.e2);
                if (!lhs || !rhs)
                {
                    bailout("bailout because either lhs or rhs for ~ could not be generated");
                    return ;
                }
                if (lhs.type.type != BCTypeEnum.Slice && (lhs.type.typeIndex <= _sharedCtfeState.sliceCount))
                {
                    bailout("lhs for concat has to be a slice not: " ~ to!string(lhs.type.type));
                    return;
                }
                auto lhsBaseType = _sharedCtfeState.sliceTypes[lhs.type.typeIndex - 1].elementType;
                if (lhsBaseType.type != BCTypeEnum.i32)
                {
                    bailout("for now only append to uint[] is supported not: " ~ to!string(lhsBaseType.type));
                    return ;
                }
                if (rhs.type.type != BCTypeEnum.Slice && rhs.type.type != BCTypeEnum.Array)
                {
                    bailout("for now only concat between T[] and T[] is supported not: " ~ to!string(lhs.type.type) ~" and " ~ to!string(rhs.type.type) ~ e.toString);
                    return ;
/*
                        // a single compatble element
                        // TODO use better memory management for slices don't just copy everything!!!
                        auto oneElementSlicePtr = genTemporary(i32Type);
                        auto oneElementSliceElement = genTemporary(i32Type);
                        //FIXME this code does currently only work with uint or int;
                        Alloc(oneElementSlicePtr, imm32(8));
                        Add3(oneElementSliceElement, oneElementSlicePtr, imm32(4));
                        Store32(oneElementSlicePtr, imm32(1));
                        Store32(oneElementSliceElement, rhs);
                        rhs = oneElementSlicePtr;
                        rhs.type = lhs.type;
                        rhs.vType = lhs.vType;
*/
                }

                auto rhsBaseType = _sharedCtfeState.elementType(rhs.type);
                if (canWorkWithType(lhsBaseType) && canWorkWithType(rhsBaseType)
                        && basicTypeSize(lhsBaseType) == basicTypeSize(rhsBaseType))
                {
                    Cat(retval, lhs, rhs, basicTypeSize(lhsBaseType));
                }
                else
                {
                    bailout("We cannot cat " ~ to!string(lhsBaseType) ~ " and " ~ to!string(rhsBaseType));
                    return ;
                }
            }
            break;

        case TOK.TOKadd, TOK.TOKmin, TOK.TOKmul, TOK.TOKdiv, TOK.TOKmod,
                TOK.TOKand, TOK.TOKor, TOK.TOKxor, TOK.TOKshr, TOK.TOKshl:
                auto lhs = genExpr(e.e1);
            auto rhs = genExpr(e.e2);
            //FIXME IMPORRANT
            // The whole rhs == retval situation should be fixed in the bc evaluator
            // since targets with native 3 address code can do this!
            if (!lhs || !rhs)
            {
                bailout("could not gen lhs or rhs for " ~ e.toString);
                return ;
            }

            if (wasAssignTo && rhs == retval)
            {
                auto retvalHeapRef = retval.heapRef;
                retval = genTemporary(rhs.type);
                retval.heapRef = retvalHeapRef;
            }

            if (canHandleBinExpTypes(lhs.type.type, rhs.type.type) && canWorkWithType(retval.type))
            {
                const oldDiscardValue = discardValue;
                discardValue = false;
                /*debug (ctfe)
                        assert(!oldDiscardValue, "A lone BinExp discarding the value is strange");
                    */
                switch (cast(int) e.op)
                {
                case TOK.TOKequal:
                    {
                        Eq3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKnotequal:
                    {
                        Neq3(retval, lhs, rhs);
                    }
                    break;
                case TOK.TOKmod:
                    {
                        Mod3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKadd:
                    {
                        Add3(retval, lhs, rhs);
                    }
                    break;
                case TOK.TOKmin:
                    {
                        Sub3(retval, lhs, rhs);
                    }
                    break;
                case TOK.TOKmul:
                    {
                        Mul3(retval, lhs, rhs);
                    }
                    break;
                case TOK.TOKdiv:
                    {
                        Div3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKand:
                    {
                        And3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKor:
                    {
/*
                        static if (is(BCGen))
                            if (lhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.i32)
                                bailout("BCGen does not suppport 32bit bit-operations");
*/
                        Or3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKxor:
                    {
                        Xor3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKshr:
                    {
                        auto maxShift = imm32(basicTypeSize(lhs.type) * 8 - 1);
                        Le3(BCValue.init, rhs, maxShift);
                        Assert(BCValue.init,
                            _sharedCtfeState.addError(e.loc,
                            "%d out of range(0..%d)", rhs, maxShift));

                        Rsh3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKshl:
                    {
                        auto maxShift = imm32(basicTypeSize(lhs.type) * 8 - 1);
                        Le3(BCValue.init, rhs, maxShift);
                        Assert(BCValue.init,
                            _sharedCtfeState.addError(e.loc,
                            "%d out of range(0..%d)", rhs, maxShift));

                        Lsh3(retval, lhs, rhs);
                    }
                    break;
                default:
                    {
                        bailout("Binary Expression " ~ to!string(e.op) ~ " unsupported");
                        return;
                    }
                }
                discardValue = oldDiscardValue;
            }

            else
            {
                bailout("Only binary operations on i32s are supported -- " ~ lhs.type.type.to!string ~ " :: " ~ rhs.type.type.to!string );
                return;
            }

            break;

        case TOK.TOKoror:
            {
                bailout("|| is unsupported at the moment");
            }
            break;

            debug (andand)
            {
        case TOK.TOKandand:
                {
                    noRetval = true;
                    // If lhs is false jump to false
                    // If lhs is true keep going
                    const oldFixupTableCount = fixupTableCount;

                    if (!lastExpr || getBoolExprLhs(e.e2) != getBoolExprRhs(e.e1))
                    {
                        auto lhs = genExpr(e.e1);
                        if (!lhs || !canWorkWithType(lhs.type))
                        {
                            bailout("could not gen lhs or could not handle it's type " ~ e.toString);
                            return ;
                        }
                        lastExpr = e.e1;

                        //auto afterLhs = genLabel();
                        //doFixup(oldFixupTableCount, &afterLhs, null);
                        fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(lhs,
                            false));
                    }
                    //HACK HACK HACK
                    if (getBoolExprLhs(e.e1) == e.e1)
                    {
                        auto rhs = genExpr(e.e2);
                        if (!rhs || !canWorkWithType(rhs.type))
                        {
                            bailout("could not gen rhs or could not handle it's type " ~ e.toString);
                            return ;
                        }
                        //lastExpr = e.e2;

                        //auto afterRhs = genLabel();

                        //doFixup(oldFixupTableCount, &afterRhs, null);
                        fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(rhs,
                            false));
                    }
                    noRetval = false;
                }

                break;
            }
        default:
            {
                bailout("BinExp.Op " ~ to!string(e.op) ~ " not handeled -- " ~ e.toString);
            }
        }

    }

    override void visit(SymOffExp se)
    {
        //bailout();
        auto vd = se.var.isVarDeclaration();
        auto fd = se.var.isFuncDeclaration();
        if (vd)
        {
            auto v = getVariable(vd);
            //retval = BCValue(v.stackAddr

            if (v)
            {
                _sharedCtfeState.pointerTypes[_sharedCtfeState.pointerCount++] = BCPointer(v.type, 1);
                retval.type = BCType(BCTypeEnum.Ptr, _sharedCtfeState.pointerCount);

                bailout(_sharedCtfeState.size(v.type) < 4, "only addresses of 32bit values or less are supported for now: " ~ se.toString);
                auto addr = genTemporary(i32Type);
                Alloc(addr, imm32(_sharedCtfeState.size(v.type)));
                Store32(addr, v);
                v.heapRef = BCHeapRef(addr);

                setVariable(vd, v);
                // register as pointer and set the variable to pointer as well;
                // since it has to be promoted to heap value now.
                retval = addr;


            }
            else
            {
                bailout("no valid variable for " ~ se.toString);
            }

        }
        else if (fd)
        {
            auto fnIdx = _sharedCtfeState.getFunctionIndex(fd);
            if (!fnIdx)
            {
                assert(!insideArgumentProcessing, "For now we must _never_ have to gen a function while inside argument processing");
                addUncompiledFunction(fd, &fnIdx);
            }
            bailout(!fnIdx, "Function could not be generated: -- " ~ fd.toString);
            BCValue fnPtr;
            if (!insideArgumentProcessing)
            {
                fnPtr = genTemporary(i32Type);
                Alloc(fnPtr, imm32(4));
                Store32(fnPtr, imm32(fnIdx));
            }
            else
            {
                fnPtr = imm32(_sharedCtfeState.heap.heapSize);
                _sharedCtfeState.heap._heap[_sharedCtfeState.heap.heapSize] = fnIdx;
                _sharedCtfeState.heap.heapSize += 4;
                //compileUncompiledFunctions();
            }
            retval = fnPtr;
            //retval.type.type = BCTypeEnum.Function; // ?
        }
        else
        {
            import ddmd.asttypename;
            bailout(se.var.toString() ~ " is not a variable declarartion but a " ~ astTypeName(se.var));
        }

    }

    override void visit(IndexExp ie)
    {

        debug (ctfe)
        {
            import std.stdio;

            writefln("IndexExp %s ... \n\tdiscardReturnValue %d", ie.toString, discardValue);
            writefln("ie.type : %s ", ie.type.toString);
        }

        //first do the ArgumentProcessing Path
        //We cannot emit any calls to the BCgen here
        //Everything has to be of made up of immediates
        if (insideArgumentProcessing)
        {
            if (ie.e1.op == TOKvar && ie.e2.op == TOKint64)
            {
                auto idx = cast(uint)(cast(IntegerExp) ie.e2).toInteger;
                if (auto vd = (cast(VarExp) ie.e1).var.isVarDeclaration)
                {
                    import ddmd.declaration : STCmanifest;

                    if ((vd.isDataseg() || vd.storage_class & STCmanifest) && !vd.isCTFE())
                    {
                        auto ci = vd.getConstInitializer();
                        if (ci && ci.op == TOKarrayliteral)
                        {
                            auto al = cast(ArrayLiteralExp) ci;
                            //auto galp = _sharedCtfeState.getGlobalArrayLiteralPointer(al);
                            retval = genExpr(al.elements.opIndex(idx));
                            return ;
                        }
                    }
                }
            }
            assert(0, "Arguments are not allowed to go here ... they shall not pass");
        }

        auto indexed = genExpr(ie.e1);

        if (!indexed || indexed.vType == BCValueType.VoidValue)
        {
            bailout("could not create indexed variable from: " ~ ie.e1.toString);
            return ;
        }
        auto length = getLength(indexed);

        currentIndexed = indexed;
        debug (ctfe)
        {
            import std.stdio;

            writeln("IndexedType", indexed.type.type.to!string);
        }
        if (!(indexed.type.type == BCTypeEnum.String
                || indexed.type.type == BCTypeEnum.Array || indexed.type.type == BCTypeEnum.Slice))
        {
            bailout("Unexpected IndexedType: " ~ to!string(indexed.type.type) ~ " ie: " ~ ie
                .toString);
            return;
        }

        bool isString = (indexed.type.type == BCTypeEnum.String);
        auto idx = genExpr(ie.e2).i32; // HACK
        BCValue ptr = genTemporary(i32Type);
        version (ctfe_noboundscheck)
        {
        }
        else
        {
            Lt3(BCValue.init, idx, length);
            Assert(BCValue.init, _sharedCtfeState.addError(ie.loc,
                "ArrayIndex %d out of bounds %d", idx, length));
        }

        auto elmType = _sharedCtfeState.elementType(indexed.type);
        int elmSize = _sharedCtfeState.size(elmType);
        if (cast(int) elmSize <= 0)
        {
            bailout("could not get Element-Type-size for: " ~ ie.toString);
            return ;
        }
        auto offset = genTemporary(i32Type);

        auto oldRetval = retval;
        retval = assignTo ? assignTo : genTemporary(elmType);
        {
            debug (ctfe)
            {
                writeln("elmType: ", elmType.type);
            }

            // We add one to go over the length;
                if (!elmType)
                {
                    bailout("could nit get elementType for: " ~ ie.toString);
                    return ;
                }

            if (isString)
            {
                if (!assignTo || assignTo.type != elmType)
                    bailout("Either we don't know the target-Type or the target type requires conversion: " ~ assignTo.type.type.to!string);
                //TODO use UTF8 intrinsic!
                bailout("apperantly we really cannot support string indexing ...");
                return ;
            }

            //TODO assert that idx is not out of bounds;
            //auto inBounds = genTemporary(BCType(BCTypeEnum.i1));
            //auto arrayLength = genTemporary(BCType(BCTypeEnum.i32));
            //Load32(arrayLength, indexed.i32);
            //Lt3(inBounds,  idx, arrayLength);

            Mul3(offset, idx, imm32(elmSize));
            Add3(ptr, offset, getBase(indexed));
            Load32(retval, ptr);
        }
    }

    void fixupBreak(uint oldBreakFixupCount, BCLabel breakHere)
    {
        foreach (Jmp; breakFixups[oldBreakFixupCount .. breakFixupCount])
        {
            endJmp(Jmp, breakHere);
        }
        breakFixupCount = oldBreakFixupCount;
    }

    void fixupContinue(uint oldContinueFixupCount, BCLabel continueHere)
    {
        lastContinue = continueHere;
        foreach (Jmp; continueFixups[oldContinueFixupCount .. continueFixupCount])
        {
            endJmp(Jmp, continueHere);
        }
        continueFixupCount = oldContinueFixupCount;
    }

    BCBlock genBlock(Statement stmt, bool setCurrent = false,
        bool costumBreakContinue = false)
    {
        BCBlock result;
        const oldBreakFixupCount = breakFixupCount;
        const oldContinueFixupCount = continueFixupCount;
        auto oldSwitchFixup = switchFixup;
        if (setCurrent)
        {
            switchFixup = null;
        }
        result.begin = genLabel();
        stmt.accept(this);
        result.end = genLabel();

        // Now let's fixup thoose breaks
        if (setCurrent)
        {
            switchFixup = oldSwitchFixup;
            if (!costumBreakContinue)
            {
                fixupContinue(oldContinueFixupCount, result.begin);
                fixupBreak(oldBreakFixupCount, result.end);
            }
        }

        return result;
    }

    override void visit(ForStatement fs)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("ForStatement %s", fs.toString);
        }

        if (fs._init)
        {
            (fs._init.accept(this));
        }

        if (fs.condition !is null && fs._body !is null)
        {
            if (fs.condition.isBool(true))
            {
                infiniteLoop(fs._body, fs.increment);
                return;
            }

            BCLabel condEval = genLabel();

            BCValue cond = genExpr(fs.condition);
            if (!cond)
            {
                bailout("For: No cond generated");
                return;
            }
            auto condJmp = beginCndJmp(cond);
            const oldContinueFixupCount = continueFixupCount;
            const oldBreakFixupCount = breakFixupCount;
            auto _body = genBlock(fs._body, true, true);
            if (fs.increment)
            {
                fs.increment.accept(this);
                fixupContinue(oldContinueFixupCount, _body.end);
            }
            genJump(condEval);
            auto afterLoop = genLabel();
            fixupBreak(oldBreakFixupCount, afterLoop);
            endCndJmp(condJmp, afterLoop);
        }
        else if (fs.condition !is null  /* && fs._body is null*/ )
        {
            BCLabel condEval = genLabel();
            BCValue condExpr = genExpr(fs.condition);
            auto condJmp = beginCndJmp(condExpr);
            if (fs.increment)
            {
                fs.increment.accept(this);
            }
            genJump(condEval);
            endCndJmp(condJmp, genLabel());
        }
        else
        { // fs.condition is null && fs._body !is null
            infiniteLoop(fs._body, fs.increment);
        }

    }

    override void visit(Expression e)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("Expression %s", e.toString);

        }
        import ddmd.asttypename;
        bailout("Cannot handle Expression: " ~ e.astTypeName ~  " :: " ~ e.toString);
    }

    override void visit(NullExp ne)
    {
        retval = BCValue.init;
        retval.vType = BCValueType.Immediate;
        retval.type.type = BCTypeEnum.Null;
        //debug (ctfe)
        //    assert(0, "I don't really know what to do on a NullExp");
    }

    override void visit(HaltExp he)
    {
        retval = BCValue.init;
        debug (ctfe)
            assert(0, "I don't really handle assert(0)");
    }

    override void visit(SliceExp se)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("SliceExp %s", se.toString);
            writefln("se.e1 %s", se.e1.toString);

            //assert(0, "Cannot handleExpression");
        }

        if (!se.lwr && !se.upr)
        {
            // "If there is no lwr and upr bound forward"
            retval = genExpr(se.e1);
        }
        else
        {
            if (insideArgumentProcessing)
            {
               bailout("currently we cannot slice during argument processing");
               return ;
            }

            auto origSlice = genExpr(se.e1);
            bailout(!origSlice, "could not get slice expr in " ~ se.toString);
            auto elmType = _sharedCtfeState.elementType(origSlice.type);
            if (!elmType)
            {
                bailout("could not get elementType for: " ~ se.e1.toString);
            }
            auto elemSize = _sharedCtfeState.size(elmType);

            auto newSlice = genTemporary(i32Type);
            Alloc(newSlice, imm32(SliceDescriptor.Size));

            // TODO assert lwr <= upr

            auto origLength = getLength(origSlice);
            if (!origLength)
            {
                bailout("could not gen origLength in " ~ se.toString);
                return ;
            }
            BCValue newLength = genTemporary(i32Type);
            BCValue lwr = genExpr(se.lwr);
            if (!lwr)
            {
                bailout("could not gen lowerBound in " ~ se.toString);
                return ;
            }

            auto upr = genExpr(se.upr);
            if (!upr)
            {
                bailout("could not gen upperBound in " ~ se.toString);
                return ;
            }

            Le3(BCValue.init, lwr.i32, upr.i32);
            Assert(BCValue.init, _sharedCtfeState.addError(se.loc, "slice [%llu .. %llu] is out of bounds", lwr, upr));
            Sub3(newLength, upr.i32, lwr.i32);

            setLength(newSlice, newLength);

            auto origBase = getBase(origSlice);
            if (!origBase)
            {
                bailout("could not gen origBase in " ~ se.toString);
                return ;
            }

            BCValue newBase = genTemporary(i32Type);
            Mul3(newBase, lwr.i32, imm32(elemSize));
            Add3(newBase, newBase, origBase);

            setBase(newSlice.i32, newBase.i32);

            retval = newSlice;
        }
    }

    override void visit(DotVarExp dve)
    {
        if (dve.e1.type.ty == Tstruct && (cast(TypeStruct) dve.e1.type).sym)
        {
            auto structDeclPtr = (cast(TypeStruct) dve.e1.type).sym;
            auto structTypeIndex = _sharedCtfeState.getStructIndex(structDeclPtr);
            if (structTypeIndex)
            {
                BCStruct _struct = _sharedCtfeState .structTypes[structTypeIndex - 1];
                import ddmd.ctfeexpr : findFieldIndexByName;

                auto vd = dve.var.isVarDeclaration;
                assert(vd);
                auto fIndex = findFieldIndexByName(structDeclPtr, vd);
                if (fIndex == -1)
                {
                    bailout("Field cannot be found " ~ dve.toString);
                    return;
                }

                if  (_struct.voidInit[fIndex])
                {
                    bailout("We don't handle struct fields that may be void");
                    return ;
                }

                int offset = _struct.offset(fIndex);
                if (offset == -1)
                {
                    bailout("Could not get field-offset of" ~ vd.toString);
                }

                debug (ctfe)
                {
                    import std.stdio;

                    writeln("getting field ", fIndex, "from ",
                        structDeclPtr.toString, " BCStruct ", _struct);
                }
                retval = (assignTo && assignTo.vType == BCValueType.StackValue) ? assignTo : genTemporary(
                    BCType(BCTypeEnum.i32));

                auto lhs = genExpr(dve.e1);
                if (lhs.type != BCTypeEnum.Struct)
                {
                    bailout(
                        "lhs.type != Struct but: " ~ to!string(lhs.type.type) ~ " " ~ dve
                        .e1.toString);
                }

                if (!(lhs.vType == BCValueType.StackValue
                        || lhs.vType == BCValueType.Parameter || lhs.vType == BCValueType.Temporary))
                {
                    bailout("Unexpected lhs-type: " ~ to!string(lhs.vType));
                    return;
                }

                auto ptr = genTemporary(BCType(BCTypeEnum.i32));
                Add3(ptr, lhs.i32, imm32(offset));
                Load32(retval.i32, ptr);
                retval.heapRef = BCHeapRef(ptr);

                debug (ctfe)
                {
                    import std.stdio;

                    writeln("dve.var : ", dve.var.toString);
                    writeln(dve.var.isVarDeclaration.offset);
                }
            }
        }
        else
        {
            bailout("Can only take members of a struct for now");
        }

    }

    override void visit(ArrayLiteralExp ale)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("ArrayLiteralExp %s insideArrayLiteralExp %d",
                ale.toString, insideArrayLiteralExp);
        }

        retval = assignTo ? assignTo : genTemporary(toBCType(ale.type));

        auto oldInsideArrayLiteralExp = insideArrayLiteralExp;
        insideArrayLiteralExp = true;

        auto elmType = toBCType(ale.type.nextOf);
        if (elmType.type != BCTypeEnum.i32 && elmType.type != BCTypeEnum.Struct)
        {
            bailout(
                "can only deal with int[] and uint[]  or structs atm. given:" ~ to!string(
                elmType.type));
            return;
        }
        auto arrayLength = cast(uint) ale.elements.dim;
        //_sharedCtfeState.getArrayIndex(ale.type);
        auto arrayType = BCArray(elmType, arrayLength);
        debug (ctfe)
        {
            writeln("Adding array of Type:  ", arrayType);
        }

        _sharedCtfeState.arrayTypes[_sharedCtfeState.arrayCount++] = arrayType;
        retval = assignTo ? assignTo.i32 : genTemporary(BCType(BCTypeEnum.i32));

        auto heapAdd = align4(_sharedCtfeState.size(elmType));

        uint allocSize = uint(SliceDescriptor.Size) + //ptr and length
            arrayLength * heapAdd;

        HeapAddr arrayAddr = HeapAddr(_sharedCtfeState.heap.heapSize);
        bailout(_sharedCtfeState.heap.heapSize + allocSize > _sharedCtfeState.heap.heapMax, "heap overflow");
        _sharedCtfeState.heap._heap[_sharedCtfeState.heap.heapSize + SliceDescriptor.LengthOffset] = arrayLength;
        _sharedCtfeState.heap._heap[_sharedCtfeState.heap.heapSize + SliceDescriptor.BaseOffset] = arrayAddr + SliceDescriptor.Size; // point to the begining of the array;
        _sharedCtfeState.heap.heapSize += SliceDescriptor.Size;

        foreach (elem; *ale.elements)
        {
            auto elexpr = genExpr(elem);
            if (elexpr.type.type == BCTypeEnum.i32)
            {
                if (elexpr.vType == BCValueType.Immediate)
                {
                    _sharedCtfeState.heap._heap[_sharedCtfeState.heap.heapSize] = elexpr.imm32;
                }
                else
                {
                    Store32(imm32(_sharedCtfeState.heap.heapSize), elexpr);
                }
                _sharedCtfeState.heap.heapSize += heapAdd;
            }
            else
            {
                bailout("ArrayElement is not an i32 but an " ~ to!string(elexpr.type.type));
                return;
            }
        }
        //        if (!oldInsideArrayLiteralExp)
        retval = imm32(arrayAddr.addr);
        retval.type = BCType(BCTypeEnum.Array, _sharedCtfeState.arrayCount);
        if (!insideArgumentProcessing)
        {

        }
        debug (ctfe)
        {
            import std.stdio;

            writeln("ArrayLiteralRetVal = ", retval.imm32);
        }
        auto insideArrayLiteralExp = oldInsideArrayLiteralExp;
    }

    override void visit(StructLiteralExp sle)
    {

        debug (ctfe)
        {
            import std.stdio;

            writefln("StructLiteralExp %s insideArrayLiteralExp %d",
                sle.toString, insideArrayLiteralExp);
        }

        auto sd = sle.sd;

        auto idx = _sharedCtfeState.getStructIndex(sd);
        if (!idx)
        {
            bailout("structType could not be found: " ~ sd.toString);
            return;
        }
        BCStruct _struct = _sharedCtfeState.structTypes[idx - 1];

        foreach (i; 0 .. _struct.memberTypeCount)
        {
            if (_struct.voidInit[i])
            {
                bailout("We don't handle structs with void initalizers ... right now");
            }
            /*    if (ty.type != BCTypeEnum.i32)
            {
                bailout( "can only deal with ints and uints atm. not: (" ~ to!string(ty.type) ~ ", " ~ to!string(
                        ty.typeIndex) ~ ")");
                return;
            }
          */
        }
        auto heap = _sharedCtfeState.heap;
        auto size = align4(_struct.size);

        retval = assignTo ? assignTo.i32 : genTemporary(BCType(BCTypeEnum.i32));
        if (!insideArgumentProcessing)
            Alloc(retval, imm32(size));
        else
        {
            retval = BCValue(HeapAddr(heap.heapSize));
            heap.heapSize += size;
        }

        uint offset = 0;
        BCValue fieldAddr = genTemporary(i32Type);
        foreach (elem; *sle.elements)
        {
            auto elexpr = genExpr(elem);
            debug (ctfe)
            {
                writeln("elExpr: ", elexpr.toString, " elem ", elem.toString);
            }
            /*
            if (elexpr.type != BCTypeEnum.i32
                    && (elexpr.vType != BCValueType.Immediate
                    || elexpr.vType != BCValueType.StackValue))
            {
                bailout("StructLiteralExp-Element " ~ elexpr.type.type.to!string
                        ~ " is currently not handeled");
                return;
            }*/
            if (!insideArgumentProcessing)
            {
                Add3(fieldAddr, retval.i32, imm32(offset));
                Store32(fieldAddr, elexpr);
            }
            else
            {
                bailout(elexpr.vType != BCValueType.Immediate, "When struct-literals are used as arguments all initializers, have to be immediates");
                heap._heap[retval.heapAddr + offset] = elexpr.imm32;
            }
            offset += align4(_sharedCtfeState.size(elexpr.type));

        }
    }

    override void visit(DollarExp de)
    {
        if (currentIndexed.type == BCTypeEnum.Array
                || currentIndexed.type == BCTypeEnum.Slice
                || currentIndexed.type == BCTypeEnum.String)
        {
            retval = getLength(currentIndexed);
            assert(retval);
        }
        else
        {
            bailout("We could not find an indexed variable for " ~ de.toString);
            return;
        }
    }

    override void visit(AddrExp ae)
    {
        retval = genExpr(ae.e1);
        //Alloc()
        //assert(0, "Dieng on Addr ?");
    }

    override void visit(ThisExp te)
    {
        import std.stdio;

        debug (ctfe)
        {
            writeln("ThisExp", te.toString);
            writeln("te.var:", te.var ? te.var.toString : "null");

        }

        retval = _this;
    }

    override void visit(ComExp ce)
    {
        Not(retval, genExpr(ce.e1));
    }

    override void visit(PtrExp pe)
    {
        bool isFunctionPtr = pe.type.ty == Tfunction;
        auto addr = genExpr(pe.e1);

        auto baseType = isFunctionPtr ? i32Type : _sharedCtfeState.elementType(addr.type);

        debug(ctfe)
        {

            import std.stdio;

            writeln("PtrExp: ", pe.toString, " = ", addr);
        }

        if (!addr)
        {
            bailout("could not gen pointee for PtrExp: "~ pe.e1.toString);
            return ;
        }

        if (assignTo)
        {
            retval = assignTo;
            assignTo = BCValue.init;
        }
        else
        {
            retval = genTemporary(baseType);
        }

        auto tmp = genTemporary(baseType);

        if (baseType.type != BCTypeEnum.i32)
        {
           bailout("can only deal with i32 ptrs at the moement");
           return ;
        }
        // FIXME when we are ready to support more then i32Ptr the direct calling of load
        // has to be replace by a genLoadForType() function that'll convert from
        // heap+representation to stack+representation.

        Load32(retval, addr);
        if (!isFunctionPtr)
        {
            retval.heapRef = BCHeapRef(addr);
        }
        else
        {
            retval.type.type = BCTypeEnum.Function;
        }


    }

    override void visit(NewExp ne)
    {
        auto ptr = genTemporary(i32Type);
        auto size = genTemporary(i32Type);
        auto type = toBCType(ne.newtype);
        auto typeSize = basicTypeSize(type);
        if (!isBasicBCType(type) && typeSize > 4)
        {
            bailout("Can only new basic Types under <=4 bytes for now");
            return;
        }
        Alloc(ptr, imm32(typeSize));
        // TODO do proper handling of the arguments to the newExp.
        auto value = ne.arguments && ne.arguments.dim == 1 ? genExpr((*ne.arguments)[0]) : imm32(0);
        Store32(ptr, value);
        retval = ptr;

    }

    override void visit(ArrayLengthExp ale)
    {
        auto array = genExpr(ale.e1);
        auto arrayType = array.type.type;
        if (arrayType == BCTypeEnum.String || arrayType == BCTypeEnum.Slice || arrayType == BCTypeEnum.Array)
        {
            retval = getLength(array);
        }
        else
        {
            bailout("We only handle Slice, Array, and String-Length for now atm. given : " ~ to!string(array.type.type) ~ " :: " ~ ale.e1.toString);
        }
    }

    void setLength(BCValue arr, BCValue newLength)
    {
        BCValue lengthPtr;
        if (SliceDescriptor.LengthOffset)
        {
            lengthPtr = genTemporary(i32Type);
            Add3(lengthPtr, arr.i32, imm32(SliceDescriptor.LengthOffset));
        }
        else
        {
            lengthPtr = arr.i32;
        }
        Store32(lengthPtr, newLength.i32);
    }

    BCValue getLength(BCValue arr)
    {
        if (arr)
        {
            BCValue length;
            if (arr.type.type == BCTypeEnum.Array)
            {
                auto idx = arr.type.typeIndex;
                assert(idx);
                length = imm32(_sharedCtfeState.arrayTypes[idx - 1].length);
            }
            else
            {
                if (insideArgumentProcessing)
                {
                    assert(arr.vType == BCValueType.Immediate);
                    length = imm32(_sharedCtfeState.heap._heap[arr.imm32 + SliceDescriptor.LengthOffset]);
                }
                else
                {
                    length = genTemporary(i32Type);
                    BCValue lengthPtr;
                    if (SliceDescriptor.LengthOffset)
                    {
                        lengthPtr = genTemporary(i32Type);
                        Add3(lengthPtr, arr.i32, imm32(SliceDescriptor.LengthOffset));
                    }
                    else
                    {
                        lengthPtr = arr.i32;
                    }
                    Load32(length, lengthPtr);
                }
            }
            return length;
        }
        else
        {
            bailout("cannot get length without a valid arr");
            return BCValue.init;
        }
    }

    void setBase(BCValue arr, BCValue newBase)
    {
        BCValue baseAddrPtr;
        if (SliceDescriptor.BaseOffset)
        {
            baseAddrPtr = genTemporary(i32Type);
            Add3(baseAddrPtr, arr.i32, imm32(SliceDescriptor.BaseOffset));
        }
        else
        {
            baseAddrPtr = arr.i32;
        }
        Store32(baseAddrPtr, newBase.i32);
    }

    BCValue getBase(BCValue arr)
    {
        if (arr)
        {
            BCValue baseAddr;
            if (insideArgumentProcessing)
            {
                assert(arr.vType == BCValueType.Immediate);
                baseAddr = imm32(_sharedCtfeState.heap._heap[arr.imm32 + SliceDescriptor.BaseOffset]);
            }
            else
            {
                baseAddr = genTemporary(i32Type);
                BCValue baseAddrPtr;
                if (SliceDescriptor.BaseOffset)
                {
                    baseAddrPtr = genTemporary(i32Type);
                    Add3(baseAddrPtr,  arr.i32, imm32(SliceDescriptor.BaseOffset));
                }
                else
                {
                    baseAddrPtr = arr.i32;
                }
                Load32(baseAddr, baseAddrPtr);
            }
            return baseAddr;
        }
        else
        {
            bailout("cannot get baseAddr without a valid arr");
            return BCValue.init;
        }
    }

    void LoadFromHeapRef(BCValue hrv)
    {
        bailout(hrv.type.type == BCTypeEnum.i64, "only support 32bit-sized pointerTypes right now");
        Load32(hrv, BCValue(hrv.heapRef));
    }

    void StoreToHeapRef(BCValue hrv)
    {
        bailout(hrv.type.type == BCTypeEnum.i64, "only support 32bit-sized pointerTypes right now");
        Store32(BCValue(hrv.heapRef), hrv);
    }

    void linkRefsCallee(VarDeclarations* parameters)
    {
        foreach (p; *parameters)
        {
            if (p.storage_class & STCref)
            {
                auto heapRef = getVariable(p);
                if (!heapRef)
                {
                    bailout("could not get heapRef for callee");
                    return ;
                }
                auto var = genTemporary(toBCType(p.type));
                var.heapRef = BCHeapRef(heapRef);
                setVariable(p, var);
            }
        }
    }
/+
    void linkRefsCaller(VarDeclarations* parameters)
    {
        foreach (p; *parameters)
        {
            if (p.storage_class & STCref)
            {
                auto var = getVariable(cast(VarDeclaration)p);
                StoreToHeapRef(var);
            }
        }
    }
+/
    override void visit(VarExp ve)
    {
        auto vd = ve.var.isVarDeclaration;
        auto symd = ve.var.isSymbolDeclaration;

        debug (ctfe)
        {
            import std.stdio;

            writefln("VarExp %s discardValue %d", ve.toString, discardValue);
            if (vd && (cast(void*) vd) in vars)
                writeln("ve.var sp : ", ((cast(void*) vd) in vars).stackAddr);
        }

        import ddmd.id : Id;
        if (ve.var.ident == Id.ctfe)
        {
            retval = imm32(1);
            return ;
        }

        if (vd)
        {
            if (vd.ident == Id.dollar)
            {
                retval = getLength(currentIndexed);
                return;
            }

            auto sv = getVariable(vd);
            debug (ctfe)
                assert(sv, "Variable " ~ ve.toString ~ " not in StackFrame");

            if (!ignoreVoid && sv.vType == BCValueType.VoidValue)
            {
                bailout("Trying to read form an uninitialized Variable: " ~ ve.toString);
                //TODO ve.error here ?
                return;
            }

            if (sv == BCValue.init)
            {
                bailout("invalid variable value");
                return;
            }

            if (sv.heapRef != BCHeapRef.init && sv.vType == BCValueType.StackValue)
            {
                LoadFromHeapRef(sv);
            }

            retval = sv;
        }
        else if (symd)
        {
            auto sds = cast(SymbolDeclaration) symd;
            assert(sds);
            auto sd = sds.dsym;
            Expressions iexps;

            foreach (ie; *sd.members)
            {
                //iexps.push(new Expression();
            }
            auto sl = new StructLiteralExp(sds.loc, sd, &iexps);
            retval = genExpr(sl);
            //assert(0, "SymbolDeclarations are not supported for now" ~ .type.size.to!string);
            //auto vs = symd in syms;

        }
        else
        {
            assert(0, "VarExpType unkown");
        }

        debug (ctfe)
        {
            import std.stdio;

            writeln("VarExp finished");
        }
    }

    override void visit(DeclarationExp de)
    {
        auto oldRetval = retval;
        auto vd = de.declaration.isVarDeclaration();

        if (!vd)
        {
            // It seems like we can ignore Declarartions which are not variables
            return;
        }

        visit(vd);
        auto var = retval;
        debug (ctfe)
        {
            import std.stdio;

            writefln("DeclarationExp %s discardValue %d", de.toString, discardValue);
            writefln("DeclarationExp.declaration: %x", cast(void*) de.declaration.isVarDeclaration);
        }
        if (vd._init)
        {
            if (vd._init.isVoidInitializer)
            {
                var.vType = BCValueType.VoidValue;
                setVariable(vd, var);
            }
            else if (auto ci = vd.getConstInitializer)
            {

                auto _init = genExpr(ci);
                if (_init.type == BCType(BCTypeEnum.i32))
                {
                    Set(var.i32, _init);
                }
                else if (_init.type.type == BCTypeEnum.Struct)
                {
                    // only works becuase the struct is a 32bit ptr;
                    // TODO we should probaby do a copy here ?
                    Set(var.i32, _init.i32);
                }
                else
                {
                    bailout("We don't know howto deal with this initializer: " ~ _init.toString);
                }

            }
            retval = var;
        }
    }

    override void visit(VarDeclaration vd)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("VarDeclaration %s discardValue %d", vd.toString, discardValue);
        }

        BCValue var;
        BCType type = toBCType(vd.type);
        bool refParam;
        if (processingParameters)
        {
            if (vd.storage_class & STCref)
            {
                type = i32Type;
            }

            var = genParameter(type);
            arguments ~= var;
            parameterTypes ~= type;
        }
        else
        {
            var = BCValue(currSp(), type);
            incSp();

            if (type.type == BCTypeEnum.Array)
            {
                auto idx = type.typeIndex;
                assert(idx);
                auto array = _sharedCtfeState.arrayTypes[idx - 1];

                Alloc(var.i32, imm32(_sharedCtfeState.size(type) + SliceDescriptor.Size));
                setLength(var.i32, array.length.imm32);
                auto baseAddr = genTemporary(i32Type);
                Add3(baseAddr, var.i32, imm32(SliceDescriptor.Size));
                setBase(var.i32, baseAddr);
            }
        }

        setVariable(vd, var);
        retval = var;
    }

    void setVariable(VarDeclaration vd, BCValue var)
    {
        vars[cast(void*) vd] = var;
    }

    static bool canHandleBinExpTypes(const BCTypeEnum lhs, const BCTypeEnum rhs) pure
    {
        return (lhs == BCTypeEnum.i32
            && rhs == BCTypeEnum.i32) || lhs == BCTypeEnum.i64
            && (rhs == BCTypeEnum.i64 || rhs == BCTypeEnum.i32);
    }

    override void visit(BinAssignExp e)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("BinAssignExp %s discardValue %d", e.toString, discardValue);
        }
        const oldDiscardValue = discardValue;
        auto oldAssignTo = assignTo;
        assignTo = BCValue.init;
        auto oldRetval = retval;
        discardValue = false;
        auto lhs = genExpr(e.e1);
        discardValue = false;
        auto rhs = genExpr(e.e2);

        if (!lhs || !rhs)
        {
            //FIXME we should not get into that situation!
            bailout("We could not gen lhs or rhs");
            return;
        }
        else if (!canHandleBinExpTypes(lhs.type, rhs.type) && _sharedCtfeState.elementType(lhs.type) != _sharedCtfeState.elementType(rhs.type))
        {
            bailout("Cannot use binExpTypes: " ~ to!string(lhs.type.type) ~ " " ~ to!string(rhs.type.type));
            return;
        }

        switch (e.op)
        {
        case TOK.TOKaddass:
            {
                Add3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.TOKminass:
            {
                Sub3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;

        case TOK.TOKorass:
            {
                 static if (is(BCGen))
                     if (lhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.i32)
                        bailout("BCGen does not suppport 32bit bit-operations");

                Or3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.TOKandass:
            {
                And3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.TOKxorass:
            {
                Xor3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.TOKshrass:
            {
                static if (is(BCGen))
                    if (lhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.i32)
                        bailout("BCGen does not suppport 32bit bit-operations");

                Rsh3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.TOKshlass:
            {
                static if (is(BCGen))
                    if (lhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.i32)
                        bailout("BCGen does not suppport 32bit bit-operations");

                Lsh3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.TOKmulass:
            {
                Mul3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.TOKdivass:
            {
                Div3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;

        case TOK.TOKcatass:
            {
                bailout("~= unsupported");
                if (lhs.type.type == BCTypeEnum.String && rhs.type.type == BCTypeEnum.String)
                {
                    bailout(lhs.vType != BCValueType.StackValue,
                        "Only StringConcats on StackValues are supported for now");

                    /*
                 * TODO scope(exit) { removeTempoary .... }
                 */

                    static if (UsePrinterBackend)
                    {
                    }
                    else
                    {
                        //StringCat(lhs, lhs, rhs);
                    }
                }
                else
                {
                    if (lhs.type.type == BCTypeEnum.Slice)
                    {
                        bailout(!lhs.type.typeIndex, "lhs for ~= is no valid slice" ~ e.toString);
                        bailout(_sharedCtfeState.elementType(lhs.type) != _sharedCtfeState.elementType(rhs.type), "rhs and lhs for ~= are not compatible");

                        auto sliceType = _sharedCtfeState.sliceTypes[lhs.type.typeIndex - 1];
                        retval = assignTo ? assignTo : genTemporary(i32Type);
                        Cat(retval, lhs, rhs, _sharedCtfeState.size(sliceType.elementType));
                    }
                    else
                    {
                        bailout("Can only concat on slices");
                        return;
                    }
                }
            }
            break;
        default:
            {
                bailout("BinAssignExp Unsupported for now" ~ e.toString);
            }
        }

        if (lhs.heapRef != BCHeapRef.init)
            StoreToHeapRef(lhs);

       //assert(discardValue);

        retval = oldDiscardValue ? oldRetval : retval;
        discardValue = oldDiscardValue;
        assignTo = oldAssignTo;
    }

    override void visit(IntegerExp ie)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("IntegerExpression %s", ie.toString);
        }

        auto bct = toBCType(ie.type);
        if (bct.type != BCTypeEnum.i32 && bct.type != BCTypeEnum.i64 && bct.type != BCTypeEnum.Char)
        {
            //NOTE this can happen with cast(char*)size_t.max for example
            bailout("We don't support IntegerExpressions with non-integer types");
        }

        // HACK regardless of the literal type we register it as 32bit if it's smaller then int.max;
        if (ie.value > uint.max)
        {
            retval = BCValue(Imm64(ie.value));
        }
        else
        {
            retval = imm32(cast(uint) ie.value);
        }
        //auto value = evaluateUlong(ie);
        //retval = value <= int.max ? imm32(cast(uint) value) : BCValue(Imm64(value));
        assert(retval.vType == BCValueType.Immediate);
    }

    override void visit(RealExp re)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("RealExp %s", re.toString);
        }

        bailout("RealExp unsupported");
    }

    override void visit(ComplexExp ce)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("ComplexExp %s", ce.toString);
        }

        bailout("ComplexExp unspported");
    }

    override void visit(StringExp se)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("StringExp %s", se.toString);
        }

        if (!se || se.sz > 1 /* || se.string[se.len] != 0*/ )
        {
            bailout("only char strings are supported for now");
            return;
        }
        uint sz = se.sz;
        assert(se.len < 2 ^^ 30, "String too big!!");
        uint length = cast(uint)se.len;


        auto heap = _sharedCtfeState.heap;
        HeapAddr stringAddr = HeapAddr(heap.heapSize);
        uint heapAdd = SliceDescriptor.Size;
        // always reserve space for the slice;
        heapAdd += length * sz;

        bailout(heap.heapSize + heapAdd > heap.heapMax, "heapMax exceeded while pushing: " ~ se.toString);
        _sharedCtfeState.heap.heapSize += heapAdd;

        auto baseAddr = stringAddr.addr + SliceDescriptor.Size;
        // first set length
        heap._heap[stringAddr.addr + SliceDescriptor.LengthOffset] = length;
        // then set base
        heap._heap[stringAddr.addr + SliceDescriptor.BaseOffset] = baseAddr;

        uint offset = baseAddr;
        foreach(c;se.string[0 .. length])
        {
            heap._heap[offset] = c;
            offset += sz;
        }

        auto stringAddrValue = imm32(stringAddr.addr);

        if (insideArgumentProcessing)
        {
            retval = stringAddrValue;
            return;
        }
        else
        {
            retval = assignTo ? assignTo : genTemporary(BCType(BCTypeEnum.String));
            Set(retval.i32, stringAddrValue);
        }
    }

    override void visit(CmpExp ce)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("CmpExp %s discardValue %d", ce.toString, discardValue);
        }
        auto oldAssignTo = assignTo ? assignTo : genTemporary(i32Type);
        assignTo = BCValue.init;
        auto lhs = genExpr(ce.e1);
        auto rhs = genExpr(ce.e2);
        if (canWorkWithType(lhs.type) && canWorkWithType(rhs.type) && canWorkWithType(oldAssignTo.type))
        {
            switch (ce.op)
            {
            case TOK.TOKlt:
                {
                    Lt3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            case TOK.TOKgt:
                {
                    Gt3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            case TOK.TOKle:
                {
                    Le3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            case TOK.TOKge:
                {
                    Ge3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            default:
                bailout("Unsupported Comparison " ~ to!string(ce.op));
            }
        }
        else
        {
            bailout(
                "CmpExp: cannot work with thoose types lhs: " ~ to!string(lhs.type.type) ~ " rhs: " ~ to!string(
                rhs.type.type));
        }
    }

    static bool canWorkWithType(const BCType bct) pure
    {
        return (bct.type == BCTypeEnum.i32 || bct.type == BCTypeEnum.i64);
    }
/*
    override void visit(ConstructExp ce)
    {
        //TODO ConstructExp is basically the same as AssignExp
        // find a way to merge those

        debug (ctfe)
        {
            import std.stdio;

            writefln("ConstructExp: %s", ce.toString);
            writefln("ConstructExp.e1: %s", ce.e1.toString);
            writefln("ConstructExp.e2: %s", ce.e2.toString);
        }
        else if (!ce.e1.type.equivalent(ce.e2.type) && !ce.type.baseElemOf.equivalent(ce.e2.type))
        {
            bailout("ConstructExp: Appearntly the types are not equivalent");
            return;
        }

        auto lhs = genExpr(ce.e1);
        auto rhs = genExpr(ce.e2);

        if (!lhs)
        {
            bailout("could not gen " ~ ce.e1.toString);
            return;
        }

        if (!rhs)
        {
            bailout("could not gen " ~ ce.e2.toString);
            return;
        }

        // do we deal with an int ?
        if (lhs.type.type == BCTypeEnum.i32)
        {

        }
        else if (lhs.type.type == BCTypeEnum.String
                || lhs.type.type == BCTypeEnum.Slice || lhs.type.type.Array)
        {

        }
        else if (lhs.type.type == BCTypeEnum.Char || lhs.type.type == BCTypeEnum.i8)
        {

        }
        else if (lhs.type.type == BCTypeEnum.i64)
        {
            Set(lhs, rhs);
            retval = lhs;
            return ;
        }
        else // we are dealing with a struct (hopefully)
        {
            assert(lhs.type.type == BCTypeEnum.Struct, to!string(lhs.type.type));

        }
        Set(lhs.i32, rhs.i32);
        retval = lhs;
    }
*/

    override void visit(AssignExp ae)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("AssignExp: %s", ae.toString);
        }
        auto oldRetval = retval;
        auto oldAssignTo = assignTo;
        const oldDiscardValue = discardValue;
        discardValue = false;

        if (ae.e1.op == TOKslice && ae.e2.op == TOKslice)
        {
            bailout("We don't handle slice assignment");
            return ;
        }

        debug (ctfe)
        {
            import std.stdio;

            writeln("ae.e1.op ", to!string(ae.e1.op));
        }

        if (ae.e1.op == TOKdotvar)
        {
            // Assignment to a struct member
            // Needs to be handled diffrently
            auto dve = cast(DotVarExp) ae.e1;
            auto _struct = dve.e1;
            if (_struct.type.ty != Tstruct)
            {
                bailout("only structs are supported for now");
                return;
            }
            auto structDeclPtr = (cast(TypeStruct) dve.e1.type).sym;
            auto structTypeIndex = _sharedCtfeState.getStructIndex(structDeclPtr);
            if (!structTypeIndex)
            {
                bailout("could not get StructType");
                return;
            }
            auto vd = dve.var.isVarDeclaration();
            assert(vd);

            import ddmd.ctfeexpr : findFieldIndexByName;

            auto fIndex = findFieldIndexByName(structDeclPtr, vd);
            assert(fIndex != -1, "field " ~ vd.toString ~ "could not be found in" ~ dve.e1.toString);
            BCStruct bcStructType = _sharedCtfeState.structTypes[structTypeIndex - 1];

            if (bcStructType.memberTypes[fIndex].type != BCTypeEnum.i32)
            {
                bailout("only i32 structMembers are supported for now ... not : " ~ to!string(bcStructType.memberTypes[fIndex].type));
                return;
            }

            if (bcStructType.voidInit[fIndex])
            {
                bailout("We don't handle void initialized struct fields");
                return ;
            }
            auto rhs = genExpr(ae.e2);
            if (!rhs)
            {
                //Not sure if this is really correct :)
                rhs = bcNull;
            }

            if (rhs.type.type != BCTypeEnum.i32)
            {
                bailout("only i32 are supported for now. not:" ~ rhs.type.type.to!string);
                return;
            }

            auto lhs = genExpr(_struct);
            if (!lhs)
            {
                bailout("could not gen: " ~ _struct.toString);
                return ;
            }

            auto ptr = genTemporary(BCType(BCTypeEnum.i32));

            Add3(ptr, lhs.i32, imm32(bcStructType.offset(fIndex)));
            Store32(ptr, rhs);
            retval = rhs;
        }
        else if (ae.e1.op == TOKarraylength)
        {
            bailout("assignment to array length does currently not work");
            return ;
        }
/*
        {
            auto ale = cast(ArrayLengthExp) ae.e1;

            // We are assigning to an arrayLength
            // This means possibly allocation and copying
            auto arrayPtr = genExpr(ale.e1);
            if (!arrayPtr)
            {
                bailout("I don't have an array to load the length from :(");
                return;
            }
            BCValue oldLength = getLength(arrayPtr);
            BCValue newLength = genExpr(ae.e2);
            auto effectiveSize = genTemporary(i32Type);
            auto elemType = toBCType(ale.e1.type);
            auto elemSize = align4(basicTypeSize(elemType));
            Mul3(effectiveSize, newLength, imm32(elemSize));
            Add3(effectiveSize, effectiveSize, imm32(uint(uint.sizeof*2)));

            typeof(beginJmp()) jmp;
            typeof(beginCndJmp()) jmp1;
            typeof(beginCndJmp()) jmp2;

            auto arrayExsitsJmp = beginCndJmp(arrayPtr.i32);
            {
                Le3(BCValue.init, oldLength, newLength);
                jmp1 = beginCndJmp(BCValue.init, true);
                {
                    auto newArrayPtr = genTemporary(i32Type);
                    auto newBase = genTemporary(i32Type);

                    Alloc(newArrayPtr, effectiveSize);
                    //NOTE: ABI the magic number 8 is derived from array layout {uint length, uint basePtr, T[length] space}
                    Add3(newBase, newArrayPtr, imm32(8));
                    setLength(newArrayPtr, newLength);
                    setBase(newArrayPtr, newBase);
                    auto copyPtr = getBase(arrayPtr);

                    Add3(arrayPtr.i32, arrayPtr.i32, imm32(8));
                    // copy old Array
                    auto tmpElem = genTemporary(i32Type);
                    auto LcopyLoop = genLabel();
                    jmp2 = beginCndJmp(oldLength);
                    {
                        Sub3(oldLength, oldLength, bcOne);
                        foreach (_; 0 .. elemSize / 4)
                        {
                            Load32(tmpElem, arrayPtr.i32);
                            Store32(copyPtr, tmpElem);
                            Add3(arrayPtr.i32, arrayPtr.i32, imm32(4));
                            Add3(copyPtr, copyPtr, imm32(4));
                        }
                        genJump(LcopyLoop);
                    }
                    endCndJmp(jmp2, genLabel());

                    Set(arrayPtr.i32, newArrayPtr);
                    jmp = beginJmp();
                }
            }
            auto LarrayDoesNotExsist = genLabel();
            endCndJmp(arrayExsitsJmp, LarrayDoesNotExsist);
            {
                auto newArrayPtr = genTemporary(i32Type);
                auto newBase = genTemporary(i32Type);
                Alloc(newArrayPtr, effectiveSize);
                setLength(newArrayPtr, newLength);
                Add3(newBase, newArrayPtr, imm32(uint(uint.sizeof*2)));
                setBase(newArrayPtr, newBase);
                Set(arrayPtr.i32, newArrayPtr);
            }
            auto Lend = genLabel();
            endCndJmp(jmp1, Lend);
            endJmp(jmp, Lend);
        }
*/
        else if (ae.e1.op == TOKindex)
        {
            auto ie = cast(IndexExp) ae.e1;
            auto indexed = genExpr(ie.e1);
            if (!indexed)
            {
                bailout("could not fetch indexed_var in " ~ ae.toString);
                return;
            }
            auto index = genExpr(ie.e2);
            if (!index)
            {
                bailout("could not fetch index in " ~ ae.toString);
                return;
            }

            if (processingArguments)
            {
                assert(indexed.vType == BCValueType.Immediate);
                assert(index.vType == BCValueType.Immediate);
                {

                }
            }

            auto length = getLength(indexed);
            auto baseAddr = getBase(indexed);

            version (ctfe_noboundscheck)
            {
            }
            else
            {
                Lt3(BCValue.init, index, length);
                Assert(BCValue.init, _sharedCtfeState.addError(ae.loc,
                    "ArrayIndex %d out of bounds %d", index, length));
            }
            auto effectiveAddr = genTemporary(i32Type);
            auto elemType = toBCType(ie.e1.type.nextOf);
            auto elemSize = _sharedCtfeState.size(elemType);
            Mul3(effectiveAddr, index, imm32(elemSize));
            Add3(effectiveAddr, effectiveAddr, baseAddr);
            if (elemSize > 4)
            {
                bailout("only 32 bit array loads are supported right now");
            }
            auto rhs = genExpr(ae.e2);
            if (!rhs)
            {
                bailout("we could not gen AssignExp[].rhs: " ~ ae.e2.toString);
                return ;
            }
            Store32(effectiveAddr, rhs.i32);
        }
        else
        {
            ignoreVoid = true;
            auto lhs = genExpr(ae.e1);
            if (!lhs)
            {
                bailout("could not gen AssignExp.lhs: " ~ ae.e1.toString);
                return ;
            }

            if (lhs.vType == BCValueType.VoidValue)
            {
                if (ae.e2.op == TOKvar)
                {
                    auto ve = cast(VarExp) ae.e2;
                    if (auto vd = ve.var.isVarDeclaration)
                    {
                        lhs.vType = BCValueType.StackValue;
                        setVariable(vd, lhs);
                    }
                }
            }
            assignTo = lhs;

            ignoreVoid = false;
            auto rhs = genExpr(ae.e2);

            debug (ctfe)
            {
                writeln("lhs :", lhs);
                writeln("rhs :", rhs);
            }
            if (!rhs)
            {
                bailout("could not get AssignExp.rhs: " ~ ae.e2.toString);
                return;
            }

            if ((lhs.type.type == BCTypeEnum.i32 || lhs.type.type == BCTypeEnum.i64) && rhs.type.type == BCTypeEnum.i32)
            {
                Set(lhs, rhs);
            }
            else if (lhs.type.type == BCTypeEnum.i64 && (rhs.type.type == BCTypeEnum.i64 || rhs.type.type == BCTypeEnum.i32))
            {
                Set(lhs, rhs);
            }
            else
            {
                if (lhs.type.type == BCTypeEnum.Ptr)
                {
                    bailout(!lhs.type.typeIndex || lhs.type.typeIndex > _sharedCtfeState.pointerCount, "pointer type invalid or not registerd");
                    auto ptrType = _sharedCtfeState.pointerTypes[lhs.type.typeIndex - 1];
                    if (rhs.type.type == BCTypeEnum.Ptr)
                    {
                        Set(lhs.i32, rhs.i32);
                    }
                    else
                    {
                        bailout(ptrType.elementType != rhs.type, "unequal types for *lhs and rhs");
                        Store32(lhs, rhs);
                     }
                }
                else if (lhs.type.type == BCTypeEnum.c8 && rhs.type.type == BCTypeEnum.c8)
                {
                    Set(lhs.i32, rhs.i32);
                }
                else if (lhs.type.type == BCTypeEnum.String && rhs.type.type == BCTypeEnum.String)
                {
                    Set(lhs.i32, rhs.i32);
                }
                else if (lhs.type.type == BCTypeEnum.Slice && rhs.type.type == BCTypeEnum.Slice)
                {
                    Set(lhs.i32, rhs.i32);
                }
                else if (lhs.type.type == BCTypeEnum.Slice && rhs.type.type == BCTypeEnum.Null)
                {
                    Set(lhs.i32, imm32(0));
                }
                else if (lhs.type.type == BCTypeEnum.Struct && rhs.type.type == BCTypeEnum.i32)
                {
                    // for some reason a a struct on the stack which is default-initalized
                    // get's the integerExp 0 of integer type as rhs
                    // Alloc(lhs, imm32(sharedCtfeState.size(lhs.type)));
                    // Allocate space for the value on the heap and store it in lhs :)
                    bailout("We cannot deal with default-initalized structs ...");

                }
                else
                {
                    bailout(
                        "I cannot work with thoose types" ~ to!string(lhs.type.type) ~ " " ~ to!string(
                        rhs.type.type) ~ " -- " ~ ae.toString);
                    return ;
                }
            }
            assignTo = lhs;
        }
        if (assignTo.heapRef != BCHeapRef.init)
            StoreToHeapRef(assignTo);

        retval = oldDiscardValue ? oldRetval : retval;
        assignTo = oldAssignTo;
        discardValue = oldDiscardValue;

    }

    override void visit(SwitchErrorStatement _)
    {
        //assert(0, "encounterd SwitchErrorStatement" ~ toString(_));
    }

    override void visit(NegExp ne)
    {
        Sub3(retval, imm32(0), genExpr(ne.e1));
    }

    override void visit(NotExp ne)
    {
        {
            retval = assignTo ? assignTo : genTemporary(i32Type);
            Eq3(retval, genExpr(ne.e1).i32, imm32(0));
        }

    }

    override void visit(UnrolledLoopStatement uls)
    {
        //FIXME This will break if UnrolledLoopStatements are nested,
        // I am not sure if this can ever happen
        if (unrolledLoopState)
        {
        //TODO this triggers in vibe.d however it still passes the tests ...
        //We need to fix this properly at some point!
        //    assert(0, "unrolled loops may not be nested");
        }
        auto _uls = UnrolledLoopState();
        unrolledLoopState = &_uls;
        uint end = cast(uint) uls.statements.dim - 1;

        foreach (stmt; *uls.statements)
        {
            auto block = genBlock(stmt);

            if (end--)
            {
                foreach (fixup; _uls.continueFixups[0 .. _uls.continueFixupCount])
                {
                    //HACK the will leave a nop in the bcgen
                    //but it will break llvm or other potential backends;
                    if (fixup.addr != block.end.addr)
                        endJmp(fixup, block.end);
                }
                _uls.continueFixupCount = 0;
            }
            else
            {
                //FIXME Be aware that a break fixup has to be checked aginst the ip
                //If there if an unrolledLoopStatement that has no statemetns in it,
                // we end up fixing the jump up to ourselfs.
                foreach (fixup; _uls.breakFixups[0 .. _uls.breakFixupCount])
                {
                    //HACK the will leave a nop in the bcgen
                    //but it will break llvm or other potential backends;
                    if (fixup.addr != block.begin.addr)
                        endJmp(fixup, block.begin);
                }
                _uls.breakFixupCount = 0;
            }
        }

        unrolledLoopState = null;
    }

    override void visit(ImportStatement _is)
    {
        // can be skipped
        return;
    }

    override void visit(AssertExp ae)
    {
        auto lhs = genExpr(ae.e1);
        if (lhs.type.type == BCTypeEnum.i32 || lhs.type.type == BCTypeEnum.Ptr || lhs.type.type == BCTypeEnum.Struct)
        {
            Assert(lhs.i32, _sharedCtfeState.addError(ae.loc,
                ae.msg ? ae.msg.toString : "Assert Failed"));
        }
        else
        {
            bailout("Non Integral expression in assert (should probably never happen) -- " ~ ae.toString());
            return;
        }
    }

    override void visit(SwitchStatement ss)
    {
        if (switchStateCount)
            bailout("We cannot deal with nested switches right now");

        switchState = &switchStates[switchStateCount++];
        switchState.beginCaseStatementsCount = 0;
        switchState.switchFixupTableCount = 0;

        scope (exit)
        {
            if (!switchStateCount)
            {
                switchState = null;
                switchFixup = null;
            }
            else
            {
                switchState = &switchState[--switchStateCount];
            }
        }

        with (switchState)
        {
            //This Transforms swtich in a series of if else construts.
            debug (ctfe)
            {
                import std.stdio;

                writefln("SwitchStatement %s", ss.toString);
            }

            auto lhs = genExpr(ss.condition);
            if (!lhs)
            {
                bailout("swtiching on undefined value " ~ ss.toString);
                return;
            }

            bool stringSwitch = lhs.type.type == BCTypeEnum.String;

            if (ss.cases.dim > beginCaseStatements.length)
                assert(0, "We will not have enough array space to store all cases for gotos");

            foreach (i, caseStmt; *(ss.cases))
            {
                switchFixup = &switchFixupTable[switchFixupTableCount];
                caseStmt.index = cast(int) i;
                // apperantly I have to set the index myself;
                bailout(caseStmt.exp.type.ty == Tint32, "cannot deal with signed swtiches");

                auto rhs = genExpr(caseStmt.exp);
                stringSwitch ? StringEq(BCValue.init, lhs, rhs) : Eq3(BCValue.init,
                    lhs, rhs);
                auto jump = beginCndJmp();
                if (caseStmt.statement)
                {
                    import ddmd.blockexit;

                    bool blockReturns = !!(caseStmt.statement.blockExit(me, false) & BEany);
                    auto caseBlock = genBlock(caseStmt.statement);
                    beginCaseStatements[beginCaseStatementsCount++] = caseBlock.begin;
                    //If the block returns regardless there is no need for a fixup
                    if (!blockReturns)
                    {
                        switchFixupTable[switchFixupTableCount++] = beginJmp();
                        switchFixup = &switchFixupTable[switchFixupTableCount];
                    }
                }
                else
                {
                    bailout("no statement in: " ~ caseStmt.toString);
                }
                endCndJmp(jump, genLabel());
            }

            if (ss.sdefault) // maybe we should check ss.sdefault.statement as well ... just to be sure ?
            {
                auto defaultBlock = genBlock(ss.sdefault.statement);
                // if you are wondering ac_jmp stands for after case jump
                foreach (ac_jmp; switchFixupTable[0 .. switchFixupTableCount])
                {
                    if (ac_jmp.fixupFor == 0)
                        endJmp(ac_jmp, defaultBlock.end);
                    else if (ac_jmp.fixupFor == -1)
                        endJmp(ac_jmp, defaultBlock.begin);
                    else
                        endJmp(ac_jmp, beginCaseStatements[ac_jmp.fixupFor - 1]);
                }
            }
            else
            {
                auto afterSwitch = genLabel();

                foreach (ac_jmp; switchFixupTable[0 .. switchFixupTableCount])
                {
                    if (ac_jmp.fixupFor == 0)
                        endJmp(ac_jmp, afterSwitch);
                    else if (ac_jmp.fixupFor != -1)
                        endJmp(ac_jmp, beginCaseStatements[ac_jmp.fixupFor - 1]);
                    else
                        assert(0, "Without a default Statement there cannot be a jump to default");
                }

            }

            //after we are done let's set thoose indexes back to zero
            //who knowns what will happen if we don't ?
            foreach (cs; *(ss.cases))
            {
                cs.index = 0;
            }
        }
    }

    override void visit(GotoCaseStatement gcs)
    {
        with (switchState)
        {
            *switchFixup = SwitchFixupEntry(beginJmp(), gcs.cs.index + 1);
            switchFixupTableCount++;
        }
    }

    override void visit(GotoDefaultStatement gd)
    {
        with (switchState)
        {
            *switchFixup = SwitchFixupEntry(beginJmp(), -1);
            switchFixupTableCount++;
        }
    }

    void addUnresolvedGoto(void* ident, BCBlockJump jmp)
    {
        foreach (i, ref unresolvedGoto; unresolvedGotos[0 .. unresolvedGotoCount])
        {
            if (unresolvedGoto.ident == ident)
            {
                unresolvedGoto.jumps[unresolvedGoto.jumpCount++] = jmp;
                return;
            }
        }

        unresolvedGotos[unresolvedGotoCount].ident = ident;
        unresolvedGotos[unresolvedGotoCount].jumpCount = 1;
        unresolvedGotos[unresolvedGotoCount++].jumps[0] = jmp;

    }

    override void visit(GotoStatement gs)
    {
        auto ident = cast(void*) gs.ident;

        if (auto labeledBlock = ident in labeledBlocks)
        {
            genJump(labeledBlock.begin);
        }
        else
        {
            addUnresolvedGoto(ident, BCBlockJump(beginJmp(), BCBlockJumpTarget.Begin));
        }
    }

    override void visit(LabelStatement ls)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("LabelStatement %s", ls.toString);
        }

        if (cast(void*) ls.ident in labeledBlocks)
        {
            bailout("We already enounterd a LabelStatement with this identifier");
            return;
        }
        auto block = genBlock(ls.statement);

        labeledBlocks[cast(void*) ls.ident] = block;

        foreach (i, ref unresolvedGoto; unresolvedGotos[0 .. unresolvedGotoCount])
        {
            if (unresolvedGoto.ident == cast(void*) ls.ident)
            {
                foreach (jmp; unresolvedGoto.jumps[0 .. unresolvedGoto.jumpCount])
                    final switch(jmp.jumpTarget)
                    {
                    case BCBlockJumpTarget.Begin :
                        endJmp(jmp.at, block.begin);
                    break;
                    case BCBlockJumpTarget.Continue :
                        endJmp(jmp.at, lastContinue);
                    break;
                    case BCBlockJumpTarget.End :
                        endJmp(jmp.at, block.end);
                    break;
                    }

                // write the last one into here and decrease the count
                auto lastGoto = &unresolvedGotos[--unresolvedGotoCount];
                // maybe we should not do this if (unresolvedGoto == lastGoto)
                // but that will happen infrequently and even if it happens is just a L1 to L1 tranfer
                // so who cares ... in fact I suspect the branch would be more expensive :)
                foreach (j; 0 .. lastGoto.jumpCount)
                {
                    unresolvedGoto.jumps[j] = lastGoto.jumps[j];
                }
                unresolvedGoto.jumpCount = lastGoto.jumpCount;

                break;
            }
        }
    }

    override void visit(ContinueStatement cs)
    {
        if (cs.ident)
        {
            if (auto target = cast(void*) cs.ident in labeledBlocks)
            {
                genJump(target.begin);
            }
            else
            {
                addUnresolvedGoto(cast(void*) cs.ident, BCBlockJump(beginJmp(), BCBlockJumpTarget.Continue));
            }
        }
        else if (unrolledLoopState)
        {
            unrolledLoopState.continueFixups[unrolledLoopState.continueFixupCount++] = beginJmp();
        }
        else
        {
            continueFixups[continueFixupCount++] = beginJmp();
        }
    }

    override void visit(BreakStatement bs)
    {
        if (bs.ident)
        {
            if (auto target = cast(void*) bs.ident in labeledBlocks)
            {
                genJump(target.end);
            }
            else
            {
                addUnresolvedGoto(cast(void*) bs.ident, BCBlockJump(beginJmp(), BCBlockJumpTarget.End));
            }

        }
        else if (switchFixup)
        {
            with (switchState)
            {
                *switchFixup = SwitchFixupEntry(beginJmp(), 0);
                switchFixupTableCount++;
            }
        }
        else if (unrolledLoopState)
        {
            debug (ctfe)
            {
                import std.stdio;

                writeln("breakFixupCount: ", breakFixupCount);
            }
            unrolledLoopState.breakFixups[unrolledLoopState.breakFixupCount++] = beginJmp();

        }
        else
        {
            breakFixups[breakFixupCount++] = beginJmp();
        }

    }

    override void visit(CallExp ce)
    {
        if (!insideFunction)
        {
            bailout("We cannot have calls outside of functions");
        }
        BCValue thisPtr;
        BCValue fnValue;
        FuncDeclaration fd;
        bool isFunctionPtr;

        //NOTE is could also be Tdelegate
        if(ce.e1.type.ty != Tfunction)
        {
            bailout("CallExp.e1.type.ty expected to be Tfunction, but got: " ~ to!string(cast(ENUMTY) ce.e1.type.ty));
            return ;
        }
        TypeFunction tf = cast (TypeFunction) ce.e1.type;
        import ddmd.asttypename;

        if (ce.e1.op == TOKvar)
        {

            auto ve = (cast(VarExp) ce.e1);
            fd = ve.var.isFuncDeclaration();
            // TODO FIXME be aware we can set isFunctionPtr here as well,
            // should we detect it
            if (!fd)
            {
                bailout("call on varexp: var was not a FuncDeclaration, but: " ~ ve.var.astTypeName);
                return ;
            }
        }
        else if (ce.e1.op == TOKdotvar)
        {
            Expression _this;
            DotVarExp dve = cast(DotVarExp)ce.e1;

            // Calling a member function
            _this = dve.e1;

            if (!dve.var || !dve.var.isFuncDeclaration())
            {
                bailout("no dve.var or it's not a funcDecl callExp -- " ~ dve.toString);
                return ;
            }
            fd = dve.var.isFuncDeclaration();
            /*
            if (_this.op == TOKdottype)
                _this = (cast(DotTypeExp)dve.e1).e1;
            }
            */
            thisPtr = genExpr(dve.e1);
        }
        else if (ce.e1.op == TOKstar)
        {
            isFunctionPtr = true;
            fnValue = genExpr(ce.e1);
        }

        if (!isFunctionPtr)
        {
            if (!fd)
            {
                bailout("could not get funcDecl" ~ astTypeName(ce.e1));
                return;
            }

            int fnIdx = _sharedCtfeState.getFunctionIndex(fd);
            if (!fnIdx && cacheBC)
            {
                // FIXME deferring can only be done if we are NOT in a closure
                // if we get here the function was not already there.
                // allocate the next free function index, take note of the function
                // and move on as if we had compiled it :)
                // by defering this we avoid a host of nasty issues!
                addUncompiledFunction(fd, &fnIdx);
            }
            if (!fnIdx)
            {
                bailout("We could not compile " ~ ce.toString);
                return;
            }
            fnValue = imm32(fnIdx);

        }

        BCValue[] bc_args;

        if (!tf)
        {
            bailout("could not get function type of " ~ ce.e1.toString);
            return ;
        }

        assert(ce.arguments);
        // NOTE: FIXME: in case of destructors parameters are null
        // investigate if there are circumstances in which this can happen.
        // Also destructor calls are most likely broken
        // TODO confirm if they work
        uint nParameters = tf.parameters ? cast(uint)tf.parameters.dim : 0;

        if (ce.arguments.dim > nParameters)
        {
            bailout("More arguments then parameters in -- " ~ ce.toString);
            return ;
        }

        bc_args.length = ce.arguments.dim + !!(thisPtr);

        foreach (i, arg; *ce.arguments)
        {
            bc_args[i] = genExpr(arg);
            if (bc_args[i].vType == BCValueType.Unknown)
            {
                bailout(arg.toString ~ "did not evaluate to a valid argument");
                return ;
            }
            if (bc_args[i].type == BCTypeEnum.i64)
            {
                bailout(arg.toString ~ "cannot safely pass 64bit arguments yet");
                return ;
            }

            if ((*tf.parameters)[i].storageClass & STCref)
            {
                auto argHeapRef = genTemporary(i32Type);
                Alloc(argHeapRef, imm32(basicTypeSize(bc_args[i].type)));
                auto origArg = bc_args[i];
                bc_args[i].heapRef = BCHeapRef(argHeapRef);
                StoreToHeapRef(bc_args[i]);
                bc_args[i] = argHeapRef;
            }
        }

        if (thisPtr)
        {
            bc_args[ce.arguments.dim] = thisPtr;
        }

        static if (is(BCFunction) && is(typeof(_sharedCtfeState.functionCount)))
        {

            if (assignTo)
            {
                retval = assignTo;
                assignTo = BCValue.init;
            }
            else
            {
                retval = genTemporary(toBCType(ce.type));
            }

            static if (is(BCGen))
            {
                if (callCount >= calls.length - 64)
                {
                    bailout("can only handle " ~ to!string(calls.length) ~ " function-calls per topLevel evaluation");
                    return ;
                }
            }

            if (!fnValue)
            {
                bailout("Function could not be generated in: " ~ ce.toString);
                return ;
            }

            Call(retval, fnValue, bc_args, ce.loc);

            //FIXME figure out what we do in the case where we have more arguments then parameters
            foreach(i, ref arg;bc_args)
            {
              if (nParameters > i && (*tf.parameters)[i].storageClass & STCref)
              {
                    auto ce_arg = (*ce.arguments)[i];
                    if (!arg)
                    {
                        bailout("No valid ref arg for " ~ ce_arg.toString());
                        return ;
                    }
                    auto origArg = genExpr(ce_arg);
                    origArg.heapRef = BCHeapRef(arg);
                    LoadFromHeapRef(origArg);
              }
            }

            import ddmd.identifier;
            /*if (fd.ident == Identifier.idPool("isGraphical"))
            {
                import std.stdio;
                writeln("igArgs :", bc_args);
            }*/
        }
        else
        {
            bailout("Functions are unsupported by backend " ~ BCGenT.stringof);
        }
        return;

    }

    override void visit(ReturnStatement rs)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("ReturnStatement %s", rs.toString);
        }
        assert(!inReturnStatement);
        assert(!discardValue, "A returnStatement cannot be in discarding Mode");
        if (rs.exp !is null)
        {
            auto retval = genExpr(rs.exp);
            if (!retval)
            {
                bailout("could not gen returnValue: " ~ rs.exp.toString);
                return ;
            }
            if (retval.type == BCTypeEnum.i32 || retval.type == BCTypeEnum.Slice
                    || retval.type == BCTypeEnum.Array || retval.type == BCTypeEnum.String || retval.type == BCTypeEnum.Struct)
                Ret(retval.i32);
            else
            {
                bailout(
                    "could not handle returnStatement with BCType " ~ to!string(retval.type.type));
                return;
            }
        }
        else
        {
            Ret(bcNull);
        }
    }

    override void visit(CastExp ce)
    {
        //FIXME make this handle casts properly
        //e.g. do truncation and so on
        debug (ctfe)
        {
            import std.stdio;

            writeln("CastExp: ", ce.toString());
            writeln("CastToBCType: ", toBCType(ce.type).type);
            writeln("CastFromBCType: ", toBCType(ce.e1.type).type);
        }

        auto toType = toBCType(ce.type);
        auto fromType = toBCType(ce.e1.type);

        retval = genExpr(ce.e1);
        if (toType == fromType)
        {
            //newCTFE does not need to cast
        }
        else if (toType.type == BCTypeEnum.Ptr)
        {
            bailout("We cannot cast pointers");
            return ;
        }
        else if (toType.type == BCTypeEnum.i32 || fromType == BCTypeEnum.i32)
        {
            // FIXME: we cast if we either cast from or to int
            // this is not correct just a stopgap
            retval.type = toType;
        }

        else if (fromType.type == BCTypeEnum.Array && fromType.typeIndex
                && toType.type == BCTypeEnum.Slice && toType.typeIndex
                && _sharedCtfeState.arrayTypes[fromType.typeIndex - 1].elementType
                == _sharedCtfeState.sliceTypes[toType.typeIndex - 1].elementType)
        {
            // e.g. cast(uint[])uint[10]
            retval.type = toType;
        }
        /*else if (fromType.type == BCTypeEnum.String
                && toType.type == BCTypeEnum.Slice && toType.typeIndex
                && _sharedCtfeState.sliceTypes[toType.typeIndex - 1].elementType.type
                == BCTypeEnum.i32)
        {
            // for the cast(ubyte[])string case
            // this needs to be revised as soon as we handle utf8/32 conversions
            // for now make an i8 slice
            _sharedCtfeState.sliceTypes[_sharedCtfeState.sliceCount++] = BCSlice(BCType(BCTypeEnum.i8));
            retval.type = BCType(BCTypeEnum.Slice, _sharedCtfeState.sliceCount);
            import std.stdio;
            writeln("created sliceType: ", _sharedCtfeState.sliceCount);
            //retval.type = toType;
        }*/
        else
        {
            bailout("CastExp unsupported: " ~ ce.toString);
        }
    }

    void infiniteLoop(Statement _body, Expression increment = null)
    {
        const oldBreakFixupCount = breakFixupCount;
        const oldContinueFixupCount = continueFixupCount;
        auto block = genBlock(_body, true, true);
        if (increment)
        {
            fixupContinue(oldContinueFixupCount, block.end);
            increment.accept(this);
        }
        genJump(block.begin);
        auto after_jmp = genLabel();
        fixupBreak(oldBreakFixupCount, after_jmp);

    }

    override void visit(ExpStatement es)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("ExpStatement %s", es.toString);
        }
        immutable oldDiscardValue = discardValue;
        discardValue = true;
        if (es.exp)
            genExpr(es.exp);
        discardValue = oldDiscardValue;
    }

    override void visit(DoStatement ds)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("DoStatement %s", ds.toString);
        }
        if (ds.condition.isBool(true))
        {
            infiniteLoop(ds._body);
        }
        else if (ds.condition.isBool(false))
        {
            genBlock(ds._body, true, false);
        }
        else
        {
            const oldContinueFixupCount = continueFixupCount;
            const oldBreakFixupCount = breakFixupCount;
            auto doBlock = genBlock(ds._body, true, true);

            auto cond = genExpr(ds.condition);
            if (!cond)
            {
                bailout("DoStatement cannot gen condition");
                return;
            }

            fixupContinue(oldContinueFixupCount, doBlock.begin);
            auto cj = beginCndJmp(cond, true);
            endCndJmp(cj, doBlock.begin);
            auto afterDo = genLabel();
            fixupBreak(oldBreakFixupCount, afterDo);
        }
    }

    override void visit(WithStatement ws)
    {

        debug (ctfe)
        {
            import std.stdio;
            import ddmd.asttypename;

            writefln("WithStatement %s", ws.toString);
            writefln("WithStatement.exp %s", ws.exp.toString);
            writefln("astTypeName(WithStatement.exp) %s", ws.exp.astTypeName);
            writefln("WithStatement.exp.op %s", ws.exp.op);
            writefln("WithStatement.wthis %s", ws.wthis.toString);
        }
        if (!ws.wthis && ws.exp.op == TOKtype)
        {
            genBlock(ws._body);
            return ;
        }
        else
            bailout("We don't handle WithStatements (execpt with(Type))");
    }

    override void visit(Statement s)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("Statement %s", s.toString);
        }
        import ddmd.asttypename;
        bailout("Statement unsupported " ~ s.astTypeName ~ " :: " ~ s.toString);
    }

    override void visit(IfStatement fs)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("IfStatement %s", fs.toString);
        }

        if (fs.condition.is__ctfe == 1 || fs.condition.isBool(true))
        {
            if (fs.ifbody)
                genBlock(fs.ifbody);
            return;
        }
        else if (fs.condition.is__ctfe == -1 || fs.condition.isBool(false))
        {
            if (fs.elsebody)
                genBlock(fs.elsebody);
            return;
        }

        uint oldFixupTableCount = fixupTableCount;
        if (fs.condition.op == TOKandand || fs.condition.op == TOKoror)
        {
            lastExpr = null;
            noRetval = true;
        }
        auto cond = genExpr(fs.condition);
        noRetval = false;
        if (!cond)
        {
            bailout("IfStatement: Could not genrate condition" ~ fs.condition.toString);
            return;
        }
        /* TODO we need to do something else if we deal with cained && and || Exps
        if (isChainedBoolExp())
        {
            BCBlock ifbody = fs.ifbody ? genBlock(fs.ifbody) : BCBlock.init;
            BCBlock elsebody = fs.elsebody ? genBlock(fs.elsebody) : BCBlock.init;
        }*/

        auto cj = beginCndJmp(cond);

        BCBlock ifbody = fs.ifbody ? genBlock(fs.ifbody) : BCBlock.init;
        auto to_end = beginJmp();
        auto elseLabel = genLabel();
        BCBlock elsebody = fs.elsebody ? genBlock(fs.elsebody) : BCBlock.init;
        endJmp(to_end, genLabel());
        endCndJmp(cj, elseLabel);
        doFixup(oldFixupTableCount, ifbody ? &ifbody.begin : null,
            elsebody ? &elsebody.begin : null);
        assert(oldFixupTableCount == fixupTableCount);

    }

    override void visit(ScopeStatement ss)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("ScopeStatement %s", ss.toString);
        }
        ss.statement.accept(this);
    }

    override void visit(CompoundStatement cs)
    {
        debug (ctfe)
        {
            import std.stdio;

            writefln("CompundStatement %s", cs.toString);
        }
        if (cs.statements !is null)
        {
            foreach (stmt; *(cs.statements))
            {
                if (stmt !is null)
                {
                    stmt.accept(this);
                }
                else
                {
                    bailout("Encounterd null Statement");
                    return;
                }
            }
        }
        else
        {
            //TODO figure out if this is an invalid case.
            //bailout("No Statements in CompoundStatement");
            return;
        }
    }
}
