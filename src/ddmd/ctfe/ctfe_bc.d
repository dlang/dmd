module ddmd.ctfe.ctfe_bc;
import ddmd.ctfe.bc_limits;
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
 * Written By Stefan Koch in 2016-17
 */

import std.conv : to;

enum perf = 0;
enum bailoutMessages = 0;
enum printResult = 0;
enum cacheBC = 1;
enum UseLLVMBackend = 0;
enum UsePrinterBackend = 0;
enum UseCBackend = 0;
enum UseGCCJITBackend = 0;
enum abortOnCritical = 1;

private static void clearArray(T)(auto ref T array, uint count)
{
        array[0 .. count] = typeof(array[0]).init;
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
                "bug2931", //temporarily to pass a test for multi-dimensional arrays
                "bug2931_2", //temporarily to pass a test for multi-dimensional arrays
//                "wrongcode3139", //temporarily to pass nested-swtich test
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
    enum BaseOffset = 0;
    enum LengthOffset = 4;
    enum CapcityOffset = 8;
    enum ExtraFlagsOffset = 12;
    enum Size = 16;
}

/// appended to a struct
/// so it's behind the last member
struct StructMetaData
{
    enum VoidInitBitfieldOffset = 0;
    enum Size = 4;
}
/// appended to union
/// behind the biggest Member
struct UnionMetaData
{
    enum VoidInitBitfieldOffset = 0;
    enum Size = bc_max_members/8;
}


static immutable smallIntegers = [BCTypeEnum.i8, BCTypeEnum.i16, BCTypeEnum.u8, BCTypeEnum.u16];

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
else static if (UseGCCJITBackend)
{
    import ddmd.ctfe.bc_gccjit_backend;

    alias BCGenT = GCCJIT_BCGen;
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

uint max (uint a, uint b)
{
    return a < b ? b : a;
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
    _sharedCtfeState.initStack();
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
    // this did not work because the first function we compile is the one we execute.
    // hence if visit another function before we bugun this one we are executing the
    // argument instead of the 'main' function

    foreach(arg;args)
    {
        import ddmd.tokens;
        if (arg.op == TOKcall)
        {
            bcv.bailout("Cannot handle calls in arguments");
        }

        if (arg.type.ty == Tfunction)
        { //TODO we need to fix this!
            static if (bailoutMessages)
                writeln("top-level function arguments are not supported");
            return null;
        }
        if (arg.type.ty == Tpointer && (cast(TypePointer)arg.type).nextOf.ty == Tfunction)
        {
            import ddmd.tokens;
            if (arg.op == TOKsymoff)
            {
                auto se = cast(SymOffExp)arg;
                auto _fd = se.var.isFuncDeclaration;
                if (!_fd) continue;
                int fnId = _sharedCtfeState.getFunctionIndex(_fd);
                if (!fnId)
                    bcv.addUncompiledFunction(_fd, &fnId);
            }

        }
    }
    bcv.me = fd;

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

        BCValue[4] errorValues;
        StopWatch sw;
        sw.start();
        bcv.beginArguments();
        BCValue[] bc_args;
        bc_args.length = args.length;
        bcv.beginArguments();
        foreach (i, arg; args)
        {
            bc_args[i] = bcv.genExpr(arg, "Arguments");
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
        else static if (UseGCCJITBackend)
        {
            assert(0, "binding to gccjit's run has still to be implemented");
        }
        else
        {
            debug (output_bc)
            {
                import std.stdio;

                writeln("I have ", _sharedCtfeState.functionCount, " functions!");
                printInstructions(bcv.gen.byteCodeArray[0 .. bcv.ip], bcv.stackMap).writeln();
            }

            auto retval = interpret_(bcv.byteCodeArray[0 .. bcv.ip], bc_args,
                &_sharedCtfeState.heap, &_sharedCtfeState.functions[0], &bcv.calls[0],
                &errorValues[0], &errorValues[1], &errorValues[2], &errorValues[3],
                &_sharedCtfeState.errors[0], _sharedCtfeState.stack[], bcv.stackMap());
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
                    writeln("Evaluated function:", fd.toString,  "(", args.map!(a => a.toString), ") => ",  exp.toString);
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

string toString(T)(T value) if (is(T : Statement) || is(T : Declaration)
        || is(T : Expression) || is(T : Dsymbol) || is(T : Type) || is(T : Initializer)
        || is(T : StructDeclaration))
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
    uint size = StructMetaData.Size;

    BCType[bc_max_members] memberTypes;
    bool[bc_max_members] voidInit;
    uint[][bc_max_members] initializers;

    string toString() const
    {
        string result;
        result ~= " Size: " ~ to!string(size);
        result ~= " MemberCount: " ~ to!string(memberTypeCount);
        result ~= " [";

        foreach(i; 0 .. memberTypeCount)
        {
            result ~= memberTypes[i].toString;
            result ~= " {" ~ to!string(offset(i)) ~ "}, ";
        }

        result ~= "]\n";

        return result;
    }

    void addField(const BCType bct, bool isVoid, uint[] initValue)
    {
        memberTypes[memberTypeCount] = bct;
        initializers[memberTypeCount].length = initValue.length;
        initializers[memberTypeCount][0 .. initValue.length] = initValue[0 .. initValue.length];
        voidInit[memberTypeCount++] = isVoid;

        size += align4(_sharedCtfeState.size(bct, true));
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
            _offset += align4(sharedCtfeState.size(t, true));
        }

        return _offset;
    }

    const uint voidInitBitfieldIndex(const int idx)
    {
        if (idx == -1)
            return -1;

        assert(voidInit[idx], "voidInitBitfieldIndex is only supposed to be called on kown voidInit fields");

        uint bitFieldIndex;

        foreach (isVoidInit; voidInit[0 .. idx])
        {
            if (isVoidInit)
                bitFieldIndex++;
        }

        return bitFieldIndex;
    }

}

struct BCUnion
{
    uint memberTypeCount;
    uint size = UnionMetaData.Size;

    BCType[bc_max_members] memberTypes;
    bool[bc_max_members] voidInit;
    uint[] initializer;

    string toString() const
    {
        string result;
        result ~= " Size: " ~ to!string(size);
        result ~= " MemberCount: " ~ to!string(memberTypeCount);
        result ~= " [";

        foreach(i; 0 .. memberTypeCount)
        {
            result ~= memberTypes[i].toString;
        }

        result ~= "]\n";

        return result;
    }

    void addField(const BCType bct, bool isVoid, uint[] initValue)
    {
        if (!memberTypeCount) // if we are on the first field set the initalizer
        {
            initializer.length = initValue.length;
            initializer[0 .. initValue.length] = initValue[0 .. initValue.length];
        }

        memberTypes[memberTypeCount] = bct;
        voidInit[memberTypeCount++] = isVoid;

        size = max(align4(_sharedCtfeState.size(bct, true)) + UnionMetaData.Size, size);
    }

}

struct SharedCtfeState(BCGenT)
{
    uint _threadLock;
    BCHeap heap;
    long[ushort.max / 4] stack; // a Stack of 64K/4 is the Hard Limit;
    StructDeclaration[bc_max_structs] structDeclpointerTypes;
    BCStruct[bc_max_structs] structTypes;

    TypeSArray[bc_max_arrays] sArrayTypePointers;
    BCArray[bc_max_arrays] arrayTypes;

    TypeDArray[bc_max_slices] dArrayTypePointers;
    BCSlice[bc_max_slices] sliceTypes;

    TypePointer[bc_max_types] pointerTypePointers;
    BCPointer[bc_max_pointers] pointerTypes;

    BCTypeVisitor btv = new BCTypeVisitor();


    uint structCount;
    uint arrayCount;
    uint sliceCount;
    uint pointerCount;
    // find a way to live without 102_000
    RetainedError[bc_max_errors] errors;
    uint errorCount;

    string typeToString(const BCType type) const
    {
        string result;

        if (type.type == BCTypeEnum.Slice || type.type == BCTypeEnum.Array)
        {
            if (type.typeIndex)
            {
                auto elemType = elementType(type);
                result = type.toString ~ "{ElementType: " ~ typeToString(elemType);
            }
            else
                result = type.toString;
        }

        else if (type.type == BCTypeEnum.Ptr)
        {
            if (type.typeIndex)
            {
                auto elemType = elementType(type);
                result = type.toString ~ "{ElementType: " ~ typeToString(elemType) ~ "} ";
            }
            else
                result = type.toString;
        }

        else if (type.type == BCTypeEnum.Struct)
        {
            if (type.typeIndex)
                result = "BCStruct: " ~ (cast()structDeclpointerTypes[type.typeIndex - 1]).toString;
            else
                result = type.toString;
        }

        else
            result = to!string(type.type) ~ ".toString: " ~ type.toString();

        return result;
    }

    const(BCType) elementType(const BCType type) pure const
    {
        if (type.type == BCTypeEnum.Slice)
            return (type.typeIndex && type.typeIndex <= sliceCount) ? sliceTypes[type.typeIndex - 1] .elementType : BCType.init;
        else if (type.type == BCTypeEnum.Ptr)
            return (type.typeIndex && type.typeIndex <= pointerCount) ? pointerTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.Array)
            return (type.typeIndex && type.typeIndex <= arrayCount) ? arrayTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.string8)
            return BCType(BCTypeEnum.c8);
        else
            return BCType.init;
    }

    uint[] initializer(const BCType type) const
    {
        assert(type.type == BCTypeEnum.Struct, "only structs can have initializers ... type passed: " ~ type.type.to!string);
        assert(type.typeIndex && type.typeIndex <= structCount, "invalid structTypeIndex passed: " ~ type.typeIndex.to!string);
        auto structType = structTypes[type.typeIndex - 1];
        uint[] result;
        uint offset;
        result.length = structType.size;

        foreach(i, init;structType.initializers[0 .. structType.memberTypeCount])
        {
            auto _size = _sharedCtfeState.size(structType.memberTypes[i]);
            auto endOffset = offset + _size;
            if (init.length == _size) result[offset .. endOffset] = init[0 .. _size];
            offset = endOffset;
        }

        return result;
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

    const(BCType) sliceOf(const BCType type) pure
    {
        foreach (uint i, st; sliceTypes[0 .. sliceCount])
        {
            if (st.elementType == type)
            {
                return BCType(BCTypeEnum.Slice, i + 1);
            }
        }

        sliceTypes[sliceCount++] = BCSlice(type);
        return BCType(BCTypeEnum.Slice, sliceCount);
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


    void initStack()
    {
        import core.stdc.string : memset;

        memset(&stack, 0, stack[0].sizeof * stack.length / 4);
    }

    void initHeap(uint maxHeapSize = 2 ^^ 25)
    {
        import ddmd.root.rmem;

        if (heap.heapMax < maxHeapSize)
        {
            void* mem = allocmemory(maxHeapSize * uint.sizeof);
            heap._heap = (cast(uint*) mem)[0 .. maxHeapSize];
            heap.heapMax = maxHeapSize;
            heap.heapSize = 100;
        }
        else
        {
            import core.stdc.string : memset;

            memset(&heap._heap[0], 0, heap._heap[0].sizeof * heap.heapSize);
            heap.heapSize = 100;
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

    extern (D) BCValue addError(Loc loc, string msg, BCValue v1 = BCValue.init, BCValue v2 = BCValue.init, BCValue v3 = BCValue.init, BCValue v4 = BCValue.init)
    {
        auto sa1 = TypedStackAddr(v1.type, v1.stackAddr);
        auto sa2 = TypedStackAddr(v2.type, v2.stackAddr);
        auto sa3 = TypedStackAddr(v3.type, v3.stackAddr);
        auto sa4 = TypedStackAddr(v4.type, v4.stackAddr);

        errors[errorCount++] = RetainedError(loc, msg, sa1, sa2, sa3, sa4);
        auto error = imm32(errorCount);
        error.vType = BCValueType.Error;
        return error;
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
        // if it's impossible to get the elemType return 0
        if (!elemType)
            return 0;
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
        //register sliceType
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

    const(BCType) endStruct(BeginStructResult* s, bool died)
    {
        if (died)
        {
            return BCType.init;
        }
        else
            return BCType(BCTypeEnum.Struct, s.structCount);
    }
    /*
    string getTypeString(BCType type)
    {

    }
    */
    const(uint) size(const BCType type, const bool isMember = false) const
    {
        static __gshared sizeRecursionCount = 1;
        sizeRecursionCount++;
        scope (exit)
        {
            sizeRecursionCount--;
        }
        import std.stdio;

        if (sizeRecursionCount > 3000)
        {
            writeln("Calling Size for (", type.type.to!string, ", ",
                type.typeIndex.to!string, ")");
            //writeln(getTypeString(bct));
            return 0;
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
                if (type.typeIndex && type.typeIndex < structCount)
                {
                    // the if above shoud really be an assert
                    // I have no idea why this even happens
                    return 0;
                }
                const (BCStruct) _struct = structTypes[type.typeIndex - 1];

                return _struct.size;

            }

        case BCTypeEnum.Array:
            {
                if(!type.typeIndex || type.typeIndex > arrayCount)
                {
                    // the if above shoud really be an assert
                    // I have no idea why this even happens
                    assert(0);
                }
                BCArray _array = arrayTypes[type.typeIndex - 1];
                debug (ctfe)
                {
                    import std.stdio;

                    writeln("ArrayElementSize :", size(_array.elementType));
                }
                return size(_array.elementType) * _array.length + SliceDescriptor.Size;
            }
        case BCTypeEnum.String:
        case BCTypeEnum.Ptr:
        case BCTypeEnum.Slice:
            {
                return SliceDescriptor.Size;
            }
        default:
            {
                debug (ctfe)
                    assert(0, "cannot get size for BCType." ~ to!string(type.type));
                return 0;
            }

        }
    }

    string toString() const pure
    {
        import std.stdio;
        string result;

        result ~= "Dumping Type-State \n";
        foreach(i, t;sliceTypes[0 .. sliceCount])
        {
            result ~= to!string(i) ~ " : " ~ t.to!string;
        }
/*
        foreach(i, t;_sharedCtfeState.structTypes[0 .. structCount])
        {
        }
        foreach(i, t;_sharedCtfeState.arrayTypes[0 .. arrayCount])
        {
        }
        foreach(i, t;_sharedCtfeState.pointerTypes[0 .. pointerCount])
        {
        }
*/
        return result;
    }
}

struct TypedStackAddr
{
    BCType type;
    StackAddr addr;
}

struct RetainedError // Name is still undecided
{
    import ddmd.tokens : Loc;

    Loc loc;
    string msg;

    TypedStackAddr v1;
    TypedStackAddr v2;
    TypedStackAddr v3;
    TypedStackAddr v4;
}

Expression toExpression(const BCValue value, Type expressionType,
    const BCHeap* heapPtr = &_sharedCtfeState.heap,
    const BCValue[4]* errorValues = null, const RetainedError* errors = null)
{
    debug (abi)
    {
            import std.stdio;
            import std.range;
            import std.algorithm;
            writefln("HeapDump: %s",
                zip(heapPtr._heap[100 .. heapPtr.heapSize], iota(100, heapPtr.heapSize, 1)).map!(e => e[1].to!string ~ ":" ~ e[0].to!string));
    }

    import ddmd.parse : Loc;
    static if (printResult)
    {
        import std.stdio;
        writeln("Calling toExpression with Type: ", (cast(ENUMTY)(expressionType.ty)).to!string, " Value:", value);
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
            assert(0, "Critical Error ... we tried to execute code outside of range");
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
        uint e3;
        uint e4;

        if (errorValues)
        {
            e1 = (*errorValues)[0].imm32;
            e2 = (*errorValues)[1].imm32;
            e3 = (*errorValues)[2].imm32;
            e4 = (*errorValues)[3].imm32;
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
            error(err.loc, err.msg.ptr, e1, e2, e3, e4);

        return CTFEExp.cantexp;
    }

    Expression createArray(BCValue arr, Type arrayType)
    {
        ArrayLiteralExp arrayResult;
        auto elemType = arrayType.nextOf;
        auto baseType = _sharedCtfeState.btv.toBCType(elemType);
        auto elemSize = _sharedCtfeState.size(baseType);
        auto arrayLength = heapPtr._heap[arr.heapAddr.addr + SliceDescriptor.LengthOffset];
        auto arrayBase = heapPtr._heap[arr.heapAddr.addr + SliceDescriptor.BaseOffset];
        debug (abi)
        {
            import std.stdio;
            import std.range;
            import std.algorithm;
            writefln("creating Array (%s[]) from {base: &%d = %d} {length: &%d = %d} Content: %s",
                _sharedCtfeState.typeToString(_sharedCtfeState.btv.toBCType(arrayType)),
                arr.heapAddr.addr + SliceDescriptor.BaseOffset, arrayBase, arr.heapAddr.addr + SliceDescriptor.LengthOffset, arrayLength,
                zip(heapPtr._heap[arrayBase .. arrayBase + arrayLength*16*4], iota(arrayBase, arrayBase + arrayLength*16, 1)).map!(e => e[1].to!string ~ ":" ~ e[0].to!string));
        }

        if (!arr.heapAddr || !arrayBase)
        {
           return new NullExp(Loc(), arrayType);
        }


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
            {
                BCValue elmVal;
                // FIXME: TODO: add the other string types here as well
                if (baseType.type.anyOf([BCTypeEnum.Array, BCTypeEnum.Slice, BCTypeEnum.Struct, BCTypeEnum.String]))
                {
                    elmVal = imm32(arrayBase + offset);
                }
                else
                {
                    elmVal = imm32(*(heapPtr._heap.ptr + arrayBase + offset));
                }
                elmExprs.insert(idx, toExpression(elmVal, elemType));
                offset += elemSize;
            }
        }

        arrayResult = new ArrayLiteralExp(Loc(), elmExprs);
        arrayResult.ownedByCtfe = OWNEDctfe;

        return arrayResult;
    }

    if (expressionType.isString)
    {
        import ddmd.lexer : Loc;

        if (!value.heapAddr)
        {
           return new NullExp(Loc(), expressionType);
        }

        auto length = heapPtr._heap[value.imm32 + SliceDescriptor.LengthOffset];
        auto base = heapPtr._heap[value.imm32 + SliceDescriptor.BaseOffset];
        uint sz = cast (uint) expressionType.nextOf().size;

        debug (abi)
        {
            import std.stdio;
            writefln("creating String from {base: &%d = %d} {length: &%d = %d}",
                value.heapAddr.addr + SliceDescriptor.BaseOffset, base, value.heapAddr.addr + SliceDescriptor.LengthOffset, length);
        }

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
/*
    case Tenum:
        {
            result = toExpression(value, (cast(TypeEnum)expressionType).toBasetype);
        }
        break;
*/
    case Tstruct:
        {
            auto sd = (cast(TypeStruct) expressionType).sym;
            auto si = _sharedCtfeState.getStructIndex(sd);
            assert(si);
            BCStruct _struct = _sharedCtfeState.structTypes[si - 1];
            auto structBegin = heapPtr._heap.ptr + value.imm32;
            Expressions* elmExprs = new Expressions();
            uint offset = 0;
            debug (abi)
            {
                import std.stdio;
                writeln("structType: ", _struct);
                writeln("StructHeapRep: ", structBegin[0 .. _struct.size]);
            }
            foreach (idx, memberType; _struct.memberTypes[0 .. _struct.memberTypeCount])
            {
                debug (abi)
                {
                    writeln("StructIdx:", si, " memberIdx: " ,  idx, " offset: ", offset);
                }
                auto type = sd.fields[idx].type;

                Expression elm;

                if (memberType.type == BCTypeEnum.i64)
                {
                    BCValue imm64;
                    imm64.vType = BCValueType.Immediate;
                    imm64.type = BCTypeEnum.i64;
                    imm64.imm64 = *(heapPtr._heap.ptr + value.heapAddr.addr + offset);
                    imm64.imm64 |= ulong(*(heapPtr._heap.ptr + value.heapAddr.addr + offset + 4)) << 32;
                    elm = toExpression(imm64, type);
                }
                else if (memberType.type.anyOf([BCTypeEnum.Slice, BCTypeEnum.Array, BCTypeEnum.Struct, BCTypeEnum.String]))
                {
                    elm = toExpression(imm32(value.imm32 + offset), type);
                }
                else
                {
                    debug (abi)
                    {
                        import std.stdio;
                        writeln("memberType: ", memberType);
                    }
                    elm = toExpression(
                        imm32(*(heapPtr._heap.ptr + value.heapAddr.addr + offset)), type);
                }
                if (!elm)
                {
                    static if (bailoutMessages)
                    {
                        import std.stdio;
                        writeln("We could not convert the sub-expression of a struct of type ", type.toString);
                    }
                    return null;
                }

                elmExprs.insert(idx, elm);
                offset += align4(_sharedCtfeState.size(memberType, true));
            }
            result = new StructLiteralExp(Loc(), sd, elmExprs);
            (cast(StructLiteralExp) result).ownedByCtfe = OWNEDctfe;
        }
        break;
    case Tsarray:
        {
            auto tsa = cast(TypeSArray) expressionType;
            assert(heapPtr._heap[value.heapAddr.addr + SliceDescriptor.LengthOffset] == evaluateUlong(tsa.dim),
                "static arrayLength mismatch: &" ~ to!string(value.heapAddr.addr + SliceDescriptor.LengthOffset) ~ " (" ~ to!string(heapPtr._heap[value.heapAddr.addr + SliceDescriptor.LengthOffset]) ~ ") != " ~ to!string(
                    evaluateUlong(tsa.dim)));
            result = createArray(value, tsa);
        } break;
    case Tarray:
        {
            auto tda = cast(TypeDArray) expressionType;
            result = createArray(value, tda);
        }
        break;
    case Tbool:
        {
            // assert(value.imm32 == 0 || value.imm32 == 1, "Not a valid bool");
            result = new IntegerExp(value.imm32);
        }
        break;
    case Tfloat32:
        {
            result = new RealExp(Loc(), *cast(float*)&value.imm32, expressionType);
        }
        break;
    case Tfloat64:
        {
            result = new RealExp(Loc(), *cast(double*)&value.imm64, expressionType);
        }
        break;
    case Tint32, Tuns32, Tint16, Tuns16, Tint8, Tuns8:
        {
            result = new IntegerExp(Loc(), value.imm32, expressionType);
        }
        break;
    case Tint64, Tuns64:
        {
            result = new IntegerExp(Loc(), value.imm64, expressionType);
        }
        break;
    case Tpointer:
        {
            //FIXME this will _probably_ only work for basic types with one level of indirection (eg, int*, uint*)
            if (expressionType.nextOf.ty == Tvoid)
            {
                static if (bailoutMessages)
                {
                    import std.stdio;
                    writeln("trying to build void ptr ... we cannot really do this");
                }
                return null;
            }
            result = new AddrExp(Loc.init,
                toExpression(imm32(*(heapPtr._heap.ptr + value.heapAddr)), expressionType.nextOf));
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
    Type topLevelType;
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
            return BCType(BCTypeEnum.i8);
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
            return BCType(BCTypeEnum.f23);
        case ENUMTY.Tfloat64:
            return BCType(BCTypeEnum.f52);
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
            if (!topLevelType)
            {
                topLevelType = t;
            }
            else if (topLevelType == t)
            {
                // struct S { S s } is illegal!
                assert(0, "This should never happen");
            }
            auto sd = (cast(TypeStruct) t).sym;
            uint structIndex = _sharedCtfeState.getStructIndex(sd);
            topLevelType = typeof(topLevelType).init;
            return structIndex ? BCType(BCTypeEnum.Struct, structIndex) : BCType.init;

        }
        else if (t.ty == Tarray)
        {
            auto tarr = (cast(TypeDArray) t);
            auto rt = BCType(BCTypeEnum.Slice, _sharedCtfeState.getSliceIndex(tarr));
            BCType et;

            if (rt)
            {
                et = _sharedCtfeState.elementType(rt);
            }
            if (!et)
            {
                rt = BCType.init;
            }

            return rt;
        }
        else if (t.ty == Tenum)
        {
            return toBCType(t.toBasetype);
        }
        else if (t.ty == Tsarray)
        {
            auto tsa = cast(TypeSArray) t;
            auto rt = BCType(BCTypeEnum.Array, _sharedCtfeState.getArrayIndex(tsa));
            BCType et;

            if (rt)
            {
                et = _sharedCtfeState.elementType(rt);
            }
            if (!et)
            {
                rt = BCType.init;
            }

            return rt;
        }
        else if (t.ty == Tpointer)
        {
/*
            if (auto pi =_sharedCtfeState.getPointerIndex(cast(TypePointer)t))
            {
                return BCType(BCTypeEnum.Ptr, pi);
            }
            else
*/
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
                    baseType != topLevelType ? toBCType(baseType) : BCType(BCTypeEnum.Struct,
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
        bool died;
        __gshared static bcv = new BCV!BCGenT; // TODO don't do this.

        addFieldLoop : foreach (mi, sMember; sd.fields)
        {
            if (sMember.type.ty == Tstruct && (cast(TypeStruct) sMember.type).sym == sd)
                assert(0, "recursive struct definition this should never happen");

            // look for previous field with the same offset
            // since we do not handle those current
            foreach(f;sd.fields[0 .. mi])
            {
                if (sMember.offset == f.offset)
                {
                    died = true;
                    break addFieldLoop;
                }
            }


            auto bcType = toBCType(sMember.type);
            if (!bcType)
            {
                // if the memberType is invalid we abort!
                died = true;
                break;
            }
            else if (sMember._init)
            {
                if (sMember._init.isVoidInitializer)
                    st.addField(bcType, true, []);
                else
                {
                    uint[] initializer;
                    import ddmd.initsem;

                    if(auto initExp = sMember._init.initializerToExpression)
                    {
                        if (!initExp.type)
                        {
                            //("initExp.type is null:  " ~ initExp.toString);
                            died = true;
                            break;//BCValue.init;
                        }


                        auto initBCValue = bcv.genExpr(initExp);
                        if (initBCValue)
                        {
                            if (initExp.type.ty == Tint32 || initExp.type.ty == Tuns32)
                            {
                                initializer = [initBCValue.imm32, 0, 0, 0];
                            }
                            else if (initExp.type.ty == Tint64 || initExp.type.ty == Tuns64)
                            {
                                initializer = [initBCValue.imm64 & uint.max, 0, 0, 0,
                                    initBCValue.imm64 >> uint.sizeof*8, 0, 0, 0];
                            }
                        }
                    }
                    else
                        assert(0, "We cannot deal with non-int initializers");
                        //FIXME change the above assert to something we can bailout on

                    st.addField(bcType, false, initializer);
                }

            }
            else
                st.addField(bcType, false, []);

        }

        _sharedCtfeState.endStruct(&st, died);
        scope(exit) bcv.clear();
    }

}

struct BCScope
{

    //    Identifier[64] identifiers;
    BCBlock[64] blocks;
}

debug = nullPtrCheck;
debug = nullAllocCheck;
//debug = ctfe;
//debug = SetLocation;
//debug = LabelLocation;

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
    uint lastLine;

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
        lastLine = 0;

        arguments = [];
        parameterTypes = [];

        processingArguments = false;
        insideArgumentProcessing = false;
        processingParameters = false;
        insideArrayLiteralExp = false;
        IGaveUp = false;
        discardValue = false;
        ignoreVoid = false;

        lastConstVd = lastConstVd.init;
        unrolledLoopState = null;
        switchFixup = null;
        switchState = null;
        me = null;
        lastContinue = typeof(lastContinue).init;

        currentIndexed = BCValue.init;
        retval = BCValue.init;
        assignTo = BCValue.init;
        boolres = BCValue.init;

        labeledBlocks.destroy();
        vars.destroy();
    }

    UnrolledLoopState* unrolledLoopState;
    SwitchState* switchState;
    SwitchFixupEntry* switchFixup;

    FuncDeclaration me;
    bool inReturnStatement;

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
    BCValue[void* ] vars;
    BCValue _this;

    VarDeclaration lastConstVd;
    typeof(gen.genLabel()) lastContinue;
    BCValue currentIndexed;

    BCValue retval;
    BCValue assignTo;
    BCValue boolres;

    bool discardValue = false;
    uint current_line;

    uint uniqueCounter = 1;

    extern(D) BCValue addError(Loc loc, string msg, BCValue v1 = BCValue.init, BCValue v2 = BCValue.init, BCValue v3 = BCValue.init, BCValue v4 = BCValue.init)
    {
        alias add_error_message_prototype = uint delegate (string);
        alias add_error_value_prototype = uint delegate (BCValue);

        static if (is(typeof(&gen.addErrorMessage) == add_error_message_prototype))
        {
            addErrorMessage(msg);
        }
        static if (is(typeof(&gen.addErrorValue) == add_error_value_prototype))
        {
            if (v1) addErrorValue(v1);
            if (v2) addErrorValue(v2);
            if (v3) addErrorValue(v3);
            if (v4) addErrorValue(v4);
        }

        if (v1)
        {
            if (v1.vType == BCValueType.Immediate)
            {
                BCValue t = genTemporary(v1.type);
                Set(t, v1);
                v1 = t;
            }
        }
        if (v2)
        {
            if (v2.vType == BCValueType.Immediate)
            {
                BCValue t = genTemporary(v2.type);
                Set(t, v2);
                v2 = t;
            }
        }
        if (v3)
        {
            if (v3.vType == BCValueType.Immediate)
            {
                BCValue t = genTemporary(v3.type);
                Set(t, v3);
                v3 = t;
            }
        }
        if (v4)
        {
            if (v4.vType == BCValueType.Immediate)
            {
                BCValue t = genTemporary(v4.type);
                Set(t, v4);
                v4 = t;
            }
        }

        return _sharedCtfeState.addError(loc, msg, v1, v2, v3, v4);
    }

    extern(D) void MemCpyConst(/*const*/ BCValue destBasePtr, /*const*/ uint[] source, uint wordSize = 4)
    {
        assert(wordSize <= 4);
        auto destPtr = genTemporary(i32Type);
        // TODO technically we should make sure that we zero the heap-portion
        // MemSet(destBasePtr, imm32(0), imm32(cast(uint)source.length));
        foreach(uint i, word;source)
        {
            if (word != 0)
            {
                Add3(destPtr, destBasePtr, imm32(wordSize*i));
                Store32(destPtr, imm32(word));
            }
        }
    }

    debug (nullPtrCheck)
    {
        import ddmd.lexer : Loc;

        void Load32(BCValue _to, BCValue from, size_t line = __LINE__)
        {
            Assert(from.i32, addError(Loc.init,
                    "Load Source may not be null - target: " ~ to!string(_to.stackAddr) ~ " inLine: " ~ to!string(line)));
            gen.Load32(_to, from);
        }

        void Store32(BCValue _to, BCValue value, size_t line = __LINE__)
        {
            Assert(_to.i32, addError(Loc.init,
                    "Store Destination may not be null - from: " ~ to!string(value.stackAddr) ~ " inLine: " ~ to!string(line)));
            gen.Store32(_to, value);
        }

    }

    debug (nullAllocCheck)
    {
        void Alloc(BCValue result, BCValue size, BCType type = BCType.init, uint line = __LINE__)
        {

            assert(size.vType != BCValueType.Immediate || size.imm32 != 0, "Null Alloc detected in line: " ~ to!string(line));
            Comment("Alloc From: " ~ to!string(line) ~  " forType: " ~ _sharedCtfeState.typeToString(type));
            gen.Alloc(result, size);
        }
    }

    debug (LabelLocation)
    {
        import std.stdio;
        typeof(gen.genLabel()) genLabel(size_t line = __LINE__)
        {
            auto l = gen.genLabel();
            Comment("genLabel from: " ~ to!string(line));
            return l;
        }
    }

    debug (SetLocation)
    {
        import std.stdio;
        void Set(BCValue lhs, BCValue rhs, size_t line = __LINE__)
        {
            if (lhs.type.type == BCTypeEnum.string8 || lhs.type.type == BCTypeEnum.string8)
            writeln("Set(", lhs.toString, ", ", rhs.toString, ") called at: ", line);
            gen.Set(lhs, rhs);
        }
    }

    void expandSliceBy(BCValue slice, BCValue expandBy)
    {
        assert(slice && slice.type.type == BCTypeEnum.Slice);
        assert(expandBy);

        auto length = getLength(slice);
        auto newLength = genTemporary(i32Type);
        Add3(newLength, length, expandBy);
        expandSliceTo(slice, newLength);
    }

    /// copyArray will advance both newBase and oldBase by length

    void copyArray(BCValue* newBase, BCValue* oldBase, BCValue length, uint elementSize)
    {
        auto _newBase = *newBase;
        auto _oldBase = *oldBase;

        auto effectiveSize = genTemporary(i32Type);
        assert(elementSize);
        Mul3(effectiveSize, length, imm32(elementSize));
        MemCpy(_newBase, _oldBase, effectiveSize);
        Add3(_newBase, _newBase, effectiveSize);
        Add3(_oldBase, _oldBase, effectiveSize);
    }

    void expandSliceTo(BCValue slice, BCValue newLength)
    {
        if((slice.type != BCTypeEnum.Slice && slice.type != BCTypeEnum.string8) && (newLength.type != BCTypeEnum.i32 && newLength.type == BCTypeEnum.i64))
        {
            bailout("We only support expansion of slices by i32 not: " ~ to!string(slice.type.type) ~ " by " ~ to!string(newLength.type.type));
            return ;
        }
        debug(nullPtrCheck)
        {
            Assert(slice.i32, addError(Loc(), "expandSliceTo: arrPtr must not be null"));
        }
        auto oldBase = getBase(slice);
        auto oldLength = getLength(slice);

        auto newBase = genTemporary(i32Type);
        auto effectiveSize = genTemporary(i32Type);

        auto elementType = _sharedCtfeState.elementType(slice.type);
        if(!elementType)
        {
            bailout("we could not get the elementType of " ~ slice.type.to!string);
            return ;
        }
        auto elementSize = _sharedCtfeState.size(elementType);

        Mul3(effectiveSize, newLength, imm32(elementSize));

        Alloc(newBase, effectiveSize);
        setBase(slice, newBase);
        setLength(slice, newLength);

        // If we are trying to expand a freshly created slice
        // we don't have to copy the old contence
        // therefore jump over the copyArray if oldBase == 0

        auto CJZeroOldBase = beginCndJmp(oldBase);
        {
            copyArray(&newBase, &oldBase, oldLength, elementSize);
        }
        endCndJmp(CJZeroOldBase, genLabel());
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
        }

        fixupTableCount = oldFixupTableCount;
    }

    extern (D) void bailout(bool value, const(char)[] message, size_t line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {
        if (value)
        {
            bailout(message, line, pfn);
        }
    }

    extern (D) void excused_bailout(const(char)[] message, size_t line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {

        const fnIdx = _sharedCtfeState.getFunctionIndex(me);
        IGaveUp = true;
        if (fnIdx)
            static if (is(BCFunction))
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(null);
            }

    }

    extern (D) void bailout(const(char)[] message, size_t line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {
        IGaveUp = true;
        import ddmd.globals;
        global.newCTFEGaveUp = true;
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
//            assert(0, "bailout on " ~ pfn ~ " (" ~ to!string(line) ~ "): " ~ message);
        }
        else
        {
            import std.stdio;
            static if (bailoutMessages)
                writefln("bailout on %s (%d): %s", pfn, line, message);
        }
    }

    void Line(uint line)
    {
        if (line && line != lastLine)
        {
            gen.Line(line);
            lastLine = line;
        }

    }

    void StringEq(BCValue result, BCValue lhs, BCValue rhs)
    {

        static if (is(typeof(StrEq3) == function)
                && is(typeof(StrEq3(BCValue.init, BCValue.init, BCValue.init)) == void))
        {
            StrEq3(result, lhs, rhs);
        }

        else
        {
            auto offset = genTemporary(BCType(BCTypeEnum.i32)); //SP[12]

            auto len1 = getLength(rhs);
            auto len2 = getLength(lhs);
            Eq3(result, len1, len2);

            auto ptr1 = getBase(lhs);
            auto ptr2 = getBase(rhs);
            Set(offset, len1);

            auto e1 = genTemporary(i32Type);
            auto e2 = genTemporary(i32Type);

            auto LbeginLoop = genLabel();
            auto cndJmp1 = beginCndJmp(offset);
            Sub3(offset, offset, imm32(1));

            Load32(e1, ptr1);
            Load32(e2, ptr2);
            Eq3(result, e1, e2);
            endCndJmp(beginCndJmp(BCValue.init, true), LbeginLoop);
            auto LendLoop = genLabel();
            endCndJmp(cndJmp1, LendLoop);
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

    void doCat(ref BCValue result, BCValue lhs, BCValue rhs)
    {
        static if (is(typeof(Cat3) == function)
                && is(typeof(Cat3(BCValue.init, BCValue.init, BCValue.init, uint.init)) == void))
        {{
            auto lhsBaseType = _sharedCtfeState.elementType(lhs.type);
            const elemSize = _sharedCtfeState.size(lhsBaseType);
            if (!elemSize)
            {
                bailout("Type has no Size " ~ lhsBaseType.to!string);
                result = BCValue.init;
                return ;
            }

            // due to limitations of the opcode-format we can only issue this
            // if the elemSize fits in one byte ...

            if (!is(BCgen) || elemSize < 255)
            {
                Cat3(result, lhs, rhs, elemSize);
                return ;
            }
        }}

        // we go here if the concat could not be done by a cat3 instruction
        {
            auto lhsOrRhs = genTemporary(i32Type);
            Or3(lhsOrRhs, lhs.i32, rhs.i32);

            // lhs == result happens when doing e = e ~ x;
            // in that case we must not the result to zero
            if (lhs != result)
                Set(result.i32, imm32(0));

            auto CJisNull = beginCndJmp(lhsOrRhs);

            auto lhsLength = getLength(lhs);
            auto rhsLength = getLength(rhs);
            auto lhsBase = getBase(lhs);
            auto rhsBase = getBase(rhs);
            auto lhsBaseType = _sharedCtfeState.elementType(lhs.type);

            auto effectiveSize = genTemporary(i32Type);
            auto newLength = genTemporary(i32Type);
            auto newBase = genTemporary(i32Type);
            auto elemSize = _sharedCtfeState.size(lhsBaseType);

            if (!elemSize)
            {
                bailout("Type has no Size " ~ lhsBaseType.to!string);
                result = BCValue.init;
                return ;
            }

            Add3(newLength, lhsLength, rhsLength);
            Mul3(effectiveSize, newLength, imm32(elemSize));
            Add3(effectiveSize, effectiveSize, imm32(SliceDescriptor.Size));

            Alloc(result, effectiveSize);
            Add3(newBase, result, imm32(SliceDescriptor.Size));

            setBase(result, newBase);
            setLength(result, newLength);

            {
                auto CJlhsIsNull = beginCndJmp(lhsBase);
                copyArray(&newBase, &lhsBase, lhsLength, elemSize);
                endCndJmp(CJlhsIsNull, genLabel());
            }

            {
                auto CJrhsIsNull = beginCndJmp(rhsBase);
                copyArray(&newBase, &rhsBase, rhsLength, elemSize);
                endCndJmp(CJrhsIsNull, genLabel());
            }

            auto LafterCopy = genLabel();
            endCndJmp(CJisNull, LafterCopy);
        }
    }

    bool isBoolExp(Expression e)
    {
        return (e && (e.op == TOKandand || e.op == TOKoror));
    }

    extern (D) BCValue genExpr(Expression expr, string debugMessage = null, uint line = __LINE__)
    {
        return genExpr(expr, false, debugMessage, line);
    }

    extern (D) BCValue genExpr(Expression expr, bool costumBoolFixup,  string debugMessage = null, uint line = __LINE__)
    {

        if (!expr)
        {
            import core.stdc.stdio; printf("%s\n", ("Calling genExpr(null) from: " ~ to!string(line) ~ "\0").ptr); //DEBUGLINE
            return BCValue.init;
        }

        debug (ctfe)
        {
            import std.stdio;
        }
        auto oldRetval = retval;
        import ddmd.asttypename;
        // import std.stdio; static string currentIndent = ""; writeln(currentIndent, "genExpr(" ~ expr.astTypeName ~ ") from: ", line, (debugMessage ? " \"" ~ debugMessage ~ "\" -- " : " -- ") ~ expr.toString); currentIndent ~= "\t"; scope (exit) currentIndent = currentIndent[0 .. $-1]; //DEBUGLINE
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
            const oldFixupTableCount = fixupTableCount;
            if (expr)
                expr.accept(this);
            if (isBoolExp(expr) && !costumBoolFixup)
            {
                if (assignTo)
                {
                    retval = assignTo.i32;
                }
                else
                {
                    retval = boolres = boolres ? boolres : genTemporary(i32Type);
                }

                if (expr.op == TOKandand)
                {
                    auto Ltrue = genLabel();
                    Set(retval, imm32(1));
                    auto JtoEnd = beginJmp();
                    auto Lfalse = genLabel();
                    Set(retval, imm32(0));
                    endJmp(JtoEnd, genLabel());
                    doFixup(oldFixupTableCount, &Ltrue, &Lfalse);
                }
                else
                {
                    auto Lfalse = genLabel();
                    Set(retval, imm32(0));
                    auto JtoEnd = beginJmp();
                    auto Ltrue = genLabel();
                    Set(retval, imm32(1));
                    endJmp(JtoEnd, genLabel());
                    doFixup(oldFixupTableCount, &Ltrue, &Lfalse);
                }
            }
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

//            if ((cast(TypeFunction)fd.type).parameters)
//                foreach(p;*(cast(TypeFunction)fd.type).parameters)
//                {
//                  if (p.defaultArg)
//                       bailout("default args unsupported");
//                }


            if (fd.hasNestedFrameRefs /*|| fd.isNested*/)
            {
                // import std.stdio; writeln("fd has closureVars:  ", fd.toString);  //DEBUGLINE
                // foreach(v;fd.closureVars)
                // {
                   // import std.stdio; writeln("closure-var: ", v.toString);  //DEBUGLINE
                // }
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
            Line(uf.fd.loc.linnum);
            beginFunction(fnIdx - 1, cast(void*)uf.fd);
            uf.fd.fbody.accept(this);

            static if (is(BCGen))
            {
                auto osp = sp;
            }

            if (uf.fd.type.nextOf.ty == Tvoid)
            {

                // insert a dummy return after void functions because they can omit a returnStatement
                Ret(bcNull);
            }
            Line(uf.fd.endloc.linnum);
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

        assert(!me || me == fd);
        me = fd;

        //HACK this filters out functions which I know produce incorrect results
        //this is only so I can see where else are problems.
        if (_blacklist.isInBlacklist(fd.ident))
        {
            bailout("Bailout on blacklisted");
            return;
        }
        import std.stdio;
        if (insideFunction)
        {
            auto fnIdx = _sharedCtfeState.getFunctionIndex(fd);
            addUncompiledFunction(fd, &fnIdx);
            return ;
        }

        //writeln("going to eval: ", fd.toString);
        Line(fd.loc.linnum);
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
                if (!fnIdx)
                {
                    fnIdx = ++_sharedCtfeState.functionCount;
                    _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd);
                }
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

            static if (is(BCGen))
            {
                auto osp2 = sp.addr;
            }

            Line(fd.endloc.linnum);
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
        Line(e.loc.linnum);
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

                    import std.stdio; writeln("canWorkWithType(expr.type) :", canWorkWithType(expr.type));
                    import std.stdio; writeln("canWorkWithType(retval.type) :", canWorkWithType(retval.type));
                    bailout("++ only i32 is supported not expr: " ~ to!string(expr.type.type) ~ "retval: " ~ to!string(retval.type.type) ~ " -- " ~ e.toString);
                    return;
                }

                if (expr.type.type != BCTypeEnum.i64)
                {
                     expr = expr.i32;
                     retval = retval.i32;
                }

                assert(expr.vType != BCValueType.Immediate,
                    "++ does not make sense as on an Immediate Value");

                discardValue = oldDiscardValue;
                Set(retval, expr);

                if (expr.type.type == BCTypeEnum.f23)
                {
                    Add3(expr, expr, BCValue(Imm23f(1.0f)));
                }
                else if (expr.type.type == BCTypeEnum.f52)
                {
                    Add3(expr, expr, BCValue(Imm52f(1.0)));
                }
                else
                {
                    Add3(expr, expr, imm32(1));
                }

                if (expr.heapRef)
                {
                    StoreToHeapRef(expr);
                }
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

                if (expr.type.type == BCTypeEnum.f23)
                {
                    Sub3(expr, expr, BCValue(Imm23f(1.0f)));
                }
                else if (expr.type.type == BCTypeEnum.f52)
                {
                    Sub3(expr, expr, BCValue(Imm52f(1.0)));
                }
                else
                {
                    if (expr.type.type == BCTypeEnum.Ptr)
                        expr = expr.i32;

                    Sub3(expr, expr, imm32(1));
                }

                if (expr.heapRef)
                {
                    StoreToHeapRef(expr);
                }
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
                    if (e.op == TOK.TOKnotequal)
                        Eq3(retval.i32, retval.i32, imm32(0));
                }
                else if (canHandleBinExpTypes(toBCType(e.e1.type), toBCType(e.e2.type)))
                {
                    goto case TOK.TOKadd;
                }
            }
            break;
        case TOK.TOKquestion:
            {
        Comment(": ? begin ");
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
        Comment("Ending cndJmp for ?: rhs");
                endJmp(toend, genLabel());
            }
            break;
        case TOK.TOKcat:
            {
                auto lhs = genExpr(e.e1, "Cat lhs");
                auto rhs = genExpr(e.e2, "Cat rhs");

                assert(retval, "Cat needs a retval!");

                if (!lhs || !rhs)
                {
                    bailout("bailout because either lhs or rhs for ~ could not be generated");
                    return ;
                }
                if (lhs.type.type != BCTypeEnum.Slice && lhs.type.type != BCTypeEnum.string8)
                {
                    bailout("lhs for concat has to be a slice not: " ~ to!string(lhs.type.type));
                    return;
                }
                auto lhsBaseType = _sharedCtfeState.elementType(lhs.type);
                if (_sharedCtfeState.size(lhsBaseType) > 4)
                {
                    bailout("for now only append to T[0].sizeof <= 4 is supported not : " ~ to!string(lhsBaseType.type));
                    return ;
                }

                auto rhsBaseType = _sharedCtfeState.elementType(rhs.type);
                if(rhsBaseType != lhsBaseType)
                {
                     bailout("for now only concat between T[] and T[] is supported not: " ~ to!string(lhs.type.type) ~" and " ~ to!string(rhs.type.type) ~ e.toString);
                     return ;
                }
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
                if ((canWorkWithType(lhsBaseType) || lhsBaseType == BCTypeEnum.c8)
                        && basicTypeSize(lhsBaseType) == basicTypeSize(rhsBaseType))
                {
                    if (!lhs.heapAddr || !rhs.heapAddr)
                    {
                        bailout("null slices are not supported");
                        return ;
                    }
                    doCat(retval, lhs, rhs);
                    bailout(!retval, "could not do cat" ~ e.toString);
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
            auto lhs = genExpr(e.e1, "BinExp lhs: " ~ to!string(e.op));
            auto rhs = genExpr(e.e2, "BinExp rhs: " ~ to!string(e.op));
            //FIXME IMPORRANT
            // The whole rhs == retval situation should be fixed in the bc evaluator
            // since targets with native 3 address code can do this!
            if (!lhs || !rhs)
            {
                bailout("could not gen lhs or rhs for " ~ e.toString);
                return ;
            }

            // FIXME HACK HACK This casts rhs and lhs to i32 if a pointer is involved
            // while this should work with 32bit pointer we should do something more
            // correct here in the long run
            if (lhs.type.type == BCTypeEnum.Ptr || rhs.type.type == BCTypeEnum.Ptr || retval.type.type == BCTypeEnum.Ptr)
            {
                lhs = lhs.i32;
                rhs = rhs.i32;
                retval = retval.i32;
            }


            if (wasAssignTo && rhs == retval)
            {
                auto retvalHeapRef = retval.heapRef;
                retval = genTemporary(rhs.type);
                retval.heapRef = retvalHeapRef;
            }

            if ((isFloat(lhs.type) && isFloat(rhs.type) && lhs.type.type == rhs.type.type) || (canHandleBinExpTypes(retval.type.type, lhs.type.type) && canHandleBinExpTypes(retval.type.type, rhs.type.type)) || (e.op == TOKmod && canHandleBinExpTypes(rhs.type.type, retval.type.type)) || ((e.op == TOKequal || e.op == TOKnotequal) && canHandleBinExpTypes(lhs.type.type, rhs.type.type)))
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
                        auto v = genTemporary(i32Type);
                        if (rhs.vType != BCValueType.Immediate || rhs.imm32 > maxShift.imm32)
                        {
                            Le3(v, rhs, maxShift);
                            Assert(v,
                                addError(e.loc,
                                "shift by %d is outside the range 0..%d", rhs, maxShift)
                            );
                        }
                        Rsh3(retval, lhs, rhs);
                    }
                    break;

                case TOK.TOKshl:
                    {
                        auto maxShift = imm32(basicTypeSize(lhs.type) * 8 - 1);
                        if (rhs.vType != BCValueType.Immediate || rhs.imm32 > maxShift.imm32)
                        {
                            auto v = genTemporary(i32Type);
                            Le3(v, rhs, maxShift);
                            Assert(v,
                                addError(e.loc,
                                "shift by %d is outside the range 0..%d", rhs, maxShift)
                            );
                        }
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
                bailout("Only binary operations on i32s are supported lhs: " ~ lhs.type.type.to!string ~ " rhs: " ~ rhs.type.type.to!string ~ " retval.type: " ~ to!string(retval.type.type) ~  " -- " ~ e.toString);
                return;
            }

            break;

        case TOK.TOKoror:
            {
                    const oldFixupTableCount = fixupTableCount;
                        {
                            Comment("|| before lhs");
                            auto lhs = genExpr(e.e1);
                            if (!lhs || !canWorkWithType(lhs.type))
                            {
                                bailout("could not gen lhs or could not handle it's type " ~ e.toString);
                                return ;
                            }

                            //auto afterLhs = genLabel();
                            //doFixup(oldFixupTableCount, null, &afterLhs);
                            fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(lhs,
                                    true));
                            Comment("|| after lhs");
                        }



                    {
                        Comment("|| before rhs");
                        auto rhs = genExpr(e.e2);

                        if (!rhs || !canWorkWithType(rhs.type))
                        {
                            bailout("could not gen rhs or could not handle it's type " ~ e.toString);
                            return ;
                        }

                        fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(rhs,
                                true));
                        Comment("|| after rhs");
                        if (isBoolExp(e.e1) && !isBoolExp(e.e2))
                        {
                            Comment("fallout ?");
                        }
                    }
            }
            break;

        case TOK.TOKandand:
                {
                   // noRetval = true;
                   //     import std.stdio;
                   //     writefln("andandExp: %s -- e1.op: %s -- e2.op: %s", e.toString, e.e1.op.to!string, e.e2.op.to!string);
                    // If lhs is false jump to false
                    // If lhs is true keep going
                    const oldFixupTableCount = fixupTableCount;
                        {
                            Comment("&& beforeLhs");
                            auto lhs = genExpr(e.e1);
                            if (!lhs || !canWorkWithType(lhs.type))
                            {
                                bailout("could not gen lhs or could not handle it's type " ~ e.toString);
                                return ;
                            }

                            //auto afterLhs = genLabel();
                            //doFixup(oldFixupTableCount, &afterLhs, null);
                            fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(lhs,
                                    false));
                            Comment("&& afterLhs");
                        }



                    {
                        Comment("&& before rhs");
                        auto rhs = genExpr(e.e2);

                        if (!rhs || !canWorkWithType(rhs.type))
                        {
                            bailout("could not gen rhs or could not handle it's type " ~ e.toString);
                            return ;
                        }

                        fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(rhs,
                                false));
                        Comment("&& afterRhs");
                    }

                break;
            }
        case TOK.TOKcomma:
            {
                genExpr(e.e1);
                retval = genExpr(e.e2);
            }
            break;
        default:
            {
                bailout("BinExp.Op " ~ to!string(e.op) ~ " not handeled -- " ~ e.toString);
            }
        }

    }

    override void visit(SymOffExp se)
    {
        Line(se.loc.linnum);
        //bailout();
        auto vd = se.var.isVarDeclaration();
        auto fd = se.var.isFuncDeclaration();
        if (vd)
        {
            auto v = getVariable(vd);
            //retval = BCValue(v.stackAddr

            if (v)
            {
                // Everything in here is highly suspicious!
                // FIXME Desgin!
                // Things which are already heapValues
                // don't need to stored ((or do they ??) ... do we need to copy) ?

                retval.type = _sharedCtfeState.pointerOf(v.type);
                if (v.type.anyOf([BCTypeEnum.Array, BCTypeEnum.Struct, BCTypeEnum.Slice]))
                {
                    bailout("HeapValues are currently unspported for SymOffExps -- " ~ se.toString);
                    return ;
                }

                bailout(v && _sharedCtfeState.size(v.type) < 4, "only addresses of 32bit values or less are supported for now: " ~ se.toString);
                auto addr = genTemporary(i32Type);
                Alloc(addr, imm32(align4(_sharedCtfeState.size(v.type))));
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
        Line(ie.loc.linnum);
        auto oldIndexed = currentIndexed;
        scope(exit) currentIndexed = oldIndexed;
/+
        auto oldAssignTo = assignTo;
        assignTo = BCValue.init;
        scope(exit) assigTo = oldAssignTo;
+/
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

        auto indexed = genExpr(ie.e1, "IndexExp.e1 e1[x]");
        if(indexed.vType == BCValueType.VoidValue && ignoreVoid)
        {
            indexed.vType = BCValueType.StackValue;
        }

        if (!indexed)
        {
            bailout("could not create indexed variable from: " ~ ie.e1.toString ~ " -- !indexed: " ~ (!indexed).to!string ~ " *  ignoreVoid: " ~ ignoreVoid.to!string);
            return ;
        }
        auto length = getLength(indexed);

        currentIndexed = indexed;
        debug (ctfe)
        {
            import std.stdio;

            writeln("IndexedType", indexed.type.type.to!string);
        }
        if (!indexed.type.type.anyOf([BCTypeEnum.String, BCTypeEnum.Array, BCTypeEnum.Slice, BCTypeEnum.Ptr]))
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
            auto v = genTemporary(i32Type);
            Lt3(v, idx, length);
            Assert(v, addError(ie.loc,
                "ArrayIndex %d out of bounds %d", idx, length));
        }

        auto elemType = _sharedCtfeState.elementType(indexed.type);
        if (!elemType)
        {
            bailout("could not get elementType for: " ~ ie.toString);
            return ;
        }

        int elemSize = _sharedCtfeState.size(elemType);
        if (cast(int) elemSize <= 0)
        {
            bailout("could not get Element-Type-size for: " ~ ie.toString);
            return ;
        }
        auto offset = genTemporary(i32Type);

        auto oldRetval = retval;
        //retval = assignTo ? assignTo : genTemporary(elemType);
        retval = genTemporary(elemType);
        {
            debug (ctfe)
            {
                writeln("elemType: ", elemType.type);
            }

            if (isString)
            {
                if (retval.type != elemType)
                    bailout("the target type requires UTF-conversion: " ~ assignTo.type.type.to!string);
                //TODO use UTF8 intrinsic!
            }

            //TODO assert that idx is not out of bounds;
            //auto inBounds = genTemporary(BCType(BCTypeEnum.i1));
            //auto arrayLength = genTemporary(BCType(BCTypeEnum.i32));
            //Load32(arrayLength, indexed.i32);
            //Lt3(inBounds,  idx, arrayLength);
            auto basePtr = getBase(indexed);
            Mul3(offset, idx, imm32(elemSize));
            Add3(ptr, offset, basePtr);
            if (!retval || !ptr)
            {
                bailout("cannot gen: " ~ ie.toString);
                return ;
            }
            retval.heapRef = BCHeapRef(ptr);

            if (elemType.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.Array, BCTypeEnum.String]))
            {
                // on structs we return the ptr!
                Set(retval.i32, ptr);
                retval.heapRef = BCHeapRef(ptr);
            }
            else if (elemSize <= 4)
                Load32(retval.i32, ptr);
            else if (elemSize == 8)
                Load64(retval.i32, ptr);
            else
            {
                bailout("can only load basicTypes (i8, i16,i32 and i64, c8, c16, c32 and f23, f52) not: " ~ elemType.toString);
                return ;
            }

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
        Line(fs.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ForStatement %s", fs.toString);
        }


        BCValue initRetval;

        if (fs._init)
        {
            assert(0, "A forStatement should never have an initializer after sema3 ?");
/*
            auto oldRetval = retval;
            fs._init.accept(this);
            initRetval = retval;
            retval = oldRetval;
*/
        }

        if (fs.condition !is null && fs._body !is null)
        {
            if (fs.condition.isBool(true))
            {
                infiniteLoop(fs._body, fs.increment);
                return;
            }

            BCLabel condEval = genLabel();

            BCValue cond = genExpr(fs.condition, "ForStatement.condition");
            if (!cond)
            {
                bailout("For: No cond generated");
                return;
            }

            auto condJmp = beginCndJmp(cond.i32);
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
            BCValue cond = genExpr(fs.condition);
            if (!cond)
            {
                bailout("No cond generated for: " ~ fs.toString);
                return ;
            }
            auto condJmp = beginCndJmp(cond.i32);
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
        Line(e.loc.linnum);
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
        Line(ne.loc.linnum);
        retval = BCValue.init;
        retval.vType = BCValueType.Immediate;
        retval.type.type = BCTypeEnum.Null;
        //debug (ctfe)
        //    assert(0, "I don't really know what to do on a NullExp");
    }

    override void visit(HaltExp he)
    {
        Line(he.loc.linnum);
        retval = BCValue.init;
        debug (ctfe)
            assert(0, "I don't really handle assert(0)");
    }

    override void visit(SliceExp se)
    {
        Line(se.loc.linnum);
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
            retval = genExpr(se.e1, "SliceExp (forwarding)");
        }
        else
        {
            const oldIndexed = currentIndexed;
            scope(exit)
                currentIndexed = oldIndexed;

            if (insideArgumentProcessing)
            {
               bailout("currently we cannot slice during argument processing");
               return ;
            }

            auto origSlice = genExpr(se.e1, "SliceExp origSlice");
            if (origSlice && origSlice.type.type != BCTypeEnum.Slice && origSlice.type.type != BCTypeEnum.string8)
            {
                bailout(!origSlice.type.type.anyOf([BCTypeEnum.Array, BCTypeEnum.Ptr]),
                    "SliceExp: Slice Ptr or Array expected but got: " ~
                     origSlice.type.type.to!string
                );
                origSlice.type = _sharedCtfeState.sliceOf(_sharedCtfeState.elementType(origSlice.type));
            }
            currentIndexed = origSlice;
            bailout(!origSlice, "could not get slice expr in " ~ se.toString);
            auto elemType = _sharedCtfeState.elementType(origSlice.type);
            if (!elemType)
            {
                bailout("could not get elementType for: " ~ se.e1.toString);
            }
            auto elemSize = _sharedCtfeState.size(elemType);

            auto newSlice = genTemporary(origSlice.type);
            Alloc(newSlice.i32, imm32(SliceDescriptor.Size), origSlice.type);

            // TODO assert lwr <= upr

            auto origLength = getLength(origSlice);
            if (!origLength)
            {
                bailout("could not gen origLength in " ~ se.toString);
                return ;
            }
            BCValue newLength = genTemporary(i32Type);
            BCValue lwr = genExpr(se.lwr, "SliceExp lwr");
            if (!lwr)
            {
                bailout("could not gen lowerBound in " ~ se.toString);
                return ;
            }

            auto upr = genExpr(se.upr, "SliceExp upr");
            if (!upr)
            {
                bailout("could not gen upperBound in " ~ se.toString);
                return ;
            }

            {
                Gt3(BCValue.init, lwr.i32, upr.i32);
                auto CJoob = beginCndJmp();

                Assert(imm32(0), addError(se.loc, "slice [%llu .. %llu] is out of bounds", lwr, upr));

                endCndJmp(CJoob, genLabel());
            }
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
        Line(dve.loc.linnum);
        if (dve.e1.type.ty == Tstruct && (cast(TypeStruct) dve.e1.type).sym)
        {
            auto structDeclPtr = (cast(TypeStruct) dve.e1.type).sym;
            auto structTypeIndex = _sharedCtfeState.getStructIndex(structDeclPtr);
            if (structTypeIndex)
            {
                BCStruct _struct = _sharedCtfeState.structTypes[structTypeIndex - 1];
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
                    return ;
                }
                BCType varType = _struct.memberTypes[fIndex];
                if (!varType)
                {
                    bailout("struct Member " ~ to!string(fIndex) ~ " has an empty type .... this must not happen! -- " ~ dve.toString);
                    return ;
                }
                debug (ctfe)
                {
                    import std.stdio;

                    writeln("getting field ", fIndex, " from ",
                        structDeclPtr.toString, " BCStruct ", _struct);
                    writeln(varType);
                }
                retval = (assignTo && assignTo.vType == BCValueType.StackValue) ? assignTo : genTemporary(
                    toBCType(dve.type));

                auto lhs = genExpr(dve.e1, "DotVarExp: dve.e1");
                if (lhs.type != BCTypeEnum.Struct)
                {
                    bailout(
                        "lhs.type != Struct but: " ~ to!string(lhs.type.type) ~ " " ~ dve
                        .e1.toString);
                }

                if (!(isStackValueOrParameter(lhs) || lhs.vType == BCValueType.Temporary))
                {
                    bailout("Unexpected lhs-type: " ~ to!string(lhs.vType));
                    return;
                }

                auto ptr = genTemporary(varType);
                Add3(ptr.i32, lhs.i32, imm32(offset));
                //FIXME horrible hack to make slice members work
                // Systematize somehow!

                if (ptr.type.type.anyOf([BCTypeEnum.Array, BCTypeEnum.Ptr, BCTypeEnum.Slice, BCTypeEnum.Struct, BCTypeEnum.String]))
                    Set(retval.i32, ptr);
                else
                    Load32(retval.i32, ptr);
                if (!ptr)
                {
                    bailout("could not gen :" ~ dve.toString);
                    return ;
                }
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
        Line(ale.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ArrayLiteralExp %s insideArrayLiteralExp %d",
                ale.toString, insideArrayLiteralExp);
        }

        auto elemType = toBCType(ale.type.nextOf);

        if (!elemType || !_sharedCtfeState.size(elemType))
        {
            bailout("elemType type is invalid or has invalid size -- " ~ ale.toString);
            return ;
        }
/*
        if (!isBasicBCType(elemType)  && elemType.type != BCTypeEnum.c8 && elemType.type != BCTypeEnum.Struct && elemType.type != BCTypeEnum.Array)
        {
            bailout(
                "can only deal with int[] and uint[]  or structs atm. given:" ~ to!string(
                elemType.type));
            return;
        }
*/
        auto arrayLength = cast(uint) ale.elements.dim;
        //_sharedCtfeState.getArrayIndex(ale.type);
        auto arrayType = BCArray(elemType, arrayLength);
        debug (ctfe)
        {
            writeln("Adding array of Type:  ", arrayType);
        }

        _sharedCtfeState.arrayTypes[_sharedCtfeState.arrayCount++] = arrayType;
        retval = assignTo ? assignTo.i32 : genTemporary(BCType(BCTypeEnum.i32));

        auto heapAdd = _sharedCtfeState.size(elemType);
        assert(heapAdd, "heapAdd was zero indicating we had an invalid type in the arrayliteral or something");

        uint allocSize = uint(SliceDescriptor.Size) + //ptr and length
            arrayLength * heapAdd;

        BCValue arrayAddr = imm32(_sharedCtfeState.heap.heapSize);
        bailout(_sharedCtfeState.heap.heapSize + allocSize > _sharedCtfeState.heap.heapMax, "heap overflow");

        _sharedCtfeState.heap._heap[arrayAddr.imm32 + SliceDescriptor.LengthOffset] = arrayLength;
        _sharedCtfeState.heap._heap[arrayAddr.imm32 + SliceDescriptor.BaseOffset] = arrayAddr.imm32 + SliceDescriptor.Size; // point to the begining of the array;
        _sharedCtfeState.heap.heapSize += align4(allocSize);

        auto oldInsideArrayLiteralExp = insideArrayLiteralExp;
        scope(exit) insideArrayLiteralExp = oldInsideArrayLiteralExp;
        // insideArrayLiteralExp = true;


        uint offset = SliceDescriptor.Size;

        foreach (elem; *ale.elements)
        {
            if (!elem)
            {
                bailout("Null Element in ArrayLiteral-Expression: " ~ ale.toString);
                return ;
            }


            auto elexpr = genExpr(elem, "ArrayLiteralElement");

            if (elexpr.type.type.anyOf([BCTypeEnum.i32, BCTypeEnum.c8, BCTypeEnum.i8, BCTypeEnum.f23]))
            {
                if (elexpr.vType == BCValueType.Immediate)
                {
                    _sharedCtfeState.heap._heap[arrayAddr.imm32 + offset] = elexpr.imm32;
                }
                else
                {
                    Store32(imm32(arrayAddr.imm32 + offset), elexpr);
                }
            }
            else if (elexpr.type.type == BCTypeEnum.i64 || elexpr.type.type == BCTypeEnum.f52)
            {
                if (elexpr.vType == BCValueType.Immediate)
                {
                    _sharedCtfeState.heap._heap[arrayAddr.imm32 + offset] = elexpr.imm64 & uint.max;
                    _sharedCtfeState.heap._heap[arrayAddr.imm32 + offset + 4] = elexpr.imm64 >> 32;
                }
                else
                {
                    Store64(imm32(arrayAddr.imm32 + offset), elexpr);
                }
            }
            else if (elexpr.type.type == BCTypeEnum.Struct)
            {
                if (!elexpr.type.typeIndex || elexpr.type.type >= _sharedCtfeState.structTypes.length)
                {
                    // this can actually never be hit because no invalid types can have a valid size
                    // bailout("We have an invalid structType in: " ~ ale.toString);
                    assert(0);
                }

                if (elexpr.vType == BCValueType.Immediate)
                {
                    immutable size_t sourceAddr = elexpr.imm32;
                    immutable size_t targetAddr = arrayAddr.imm32 + offset;

                    _sharedCtfeState.heap._heap[targetAddr .. targetAddr + heapAdd] =
                        _sharedCtfeState.heap._heap[sourceAddr .. sourceAddr + heapAdd];
                }
                else
                {
                    auto elexpr_sv = elexpr.i32;
                    elexpr_sv.vType = BCValueType.StackValue;

                    MemCpy(imm32(arrayAddr.imm32 + offset), elexpr_sv, imm32(heapAdd));
                }
            }
            else if (elexpr.type.type.anyOf([BCTypeEnum.Array, BCTypeEnum.Slice, BCTypeEnum.String]))
            {
                if (elexpr.type.type == BCTypeEnum.Array && (!elexpr.type.typeIndex || elexpr.type.typeIndex > _sharedCtfeState.arrayCount))
                {
                    // this can actually never be hit because no invalid types can have a valid size
                    bailout("We have an invalid ArrayType in: " ~ ale.toString);
                    return ;
                    //assert(0);
                }

                if (elexpr.type.type == BCTypeEnum.Slice && (!elexpr.type.typeIndex || elexpr.type.typeIndex > _sharedCtfeState.sliceCount))
                {
                    // this can actually never be hit because no invalid types can have a valid size
                    bailout("We have an invalid SliceType in: " ~ ale.toString);
                    return ;
                    //assert(0);
                }

                if (elexpr.vType == BCValueType.Immediate)
                {

                    immutable size_t sourceAddr = elexpr.imm32;
                    immutable size_t targetAddr = arrayAddr.imm32 + offset;

                    _sharedCtfeState.heap._heap[targetAddr .. targetAddr + heapAdd] =
                        _sharedCtfeState.heap._heap[sourceAddr .. sourceAddr + heapAdd];

                }
                else
                {
                    auto elexpr_sv = elexpr.i32;
                    elexpr_sv.vType = BCValueType.StackValue;

                    MemCpy(imm32(arrayAddr.imm32 + offset), elexpr_sv, imm32(heapAdd));
                    Comment("Runtime Array of Array/Slice");
                }
            }
            else
            {
                bailout("ArrayElement is not an i32, i64, f23, f52 or Struct - but a " ~ _sharedCtfeState.typeToString(elexpr.type) ~ " -- " ~ ale.toString);
                return;
            }

            offset += heapAdd;
        }
        //        if (!oldInsideArrayLiteralExp)
        retval = arrayAddr;
        retval.type = BCType(BCTypeEnum.Array, _sharedCtfeState.arrayCount);
        if (!insideArgumentProcessing)
        {

        }
        debug (ctfe)
        {
            import std.stdio;

            writeln("ArrayLiteralRetVal = ", retval.imm32);
        }
    }

    override void visit(StructLiteralExp sle)
    {
        Line(sle.loc.linnum);

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

            auto ty = _struct.memberTypes[i];
            if (!ty.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.String, BCTypeEnum.Slice, BCTypeEnum.Array, BCTypeEnum.i8, BCTypeEnum.i32, BCTypeEnum.i64]))
            {
                bailout( "can only deal with ints and uints atm. not: (" ~ to!string(ty.type) ~ ", " ~ to!string(
                        ty.typeIndex) ~ ")");
                return;
            }
        }

        auto struct_size = align4(_struct.size);

        BCValue structVal;
        if (!struct_size)
        {
            bailout("invalid struct size! (someone really messed up here!!)");
            return ;
        }
        if (!insideArgumentProcessing)
        {
            structVal = assignTo ? assignTo : genTemporary(BCType(BCTypeEnum.Struct, idx));
            Alloc(structVal.i32, imm32(struct_size), BCType(BCTypeEnum.Struct, idx));
        }
        else
        {
            structVal = imm32(_sharedCtfeState.heap.heapSize);
            sharedCtfeState.heap.heapSize += align4(struct_size);
        }

        structVal.type = BCType(BCTypeEnum.Struct, idx);

        auto rv_stackValue = structVal.i32;
        rv_stackValue.vType = BCValueType.StackValue;
        MemCpyConst(rv_stackValue, _sharedCtfeState.initializer(BCType(BCTypeEnum.Struct, idx)));

        uint offset = 0;
        BCValue fieldAddr = genTemporary(i32Type);
        foreach (elem; *sle.elements)
        {
            Comment("StructLiteralExp element: " ~ elem.toString);
            if (!elem)
            {
                bailout("NullElement encountered in: " ~ sle.toString);
                return ;
            }
            auto elexpr = genExpr(elem, "StructLiteralExp element");
            immutable _size = _sharedCtfeState.size(elexpr.type, true);

            debug (ctfe)
            {
                writeln("elExpr: ", elexpr.toString, " elem ", elem.toString);
            }

            if (!elexpr)
            {
                bailout("could not gen StructMember: " ~ elem.toString);
                return ;
            }

            if (!insideArgumentProcessing)
            {
                if (offset)
                    Add3(fieldAddr, rv_stackValue, imm32(offset));
                else
                    Set(fieldAddr, rv_stackValue);
                // abi hack for slices slice;
                if (elexpr.type.type.anyOf([BCTypeEnum.Slice, BCTypeEnum.Array, BCTypeEnum.Struct, BCTypeEnum.String, BCTypeEnum.Ptr]))
                {
                    // copy Member
                    MemCpy(fieldAddr, elexpr, imm32(_size));
                }
                else if (basicTypeSize(elexpr.type.type) == 8)
                    Store64(fieldAddr, elexpr);
                else if (basicTypeSize(elexpr.type.type) && basicTypeSize(elexpr.type.type) <= 4)
                    Store32(fieldAddr, elexpr);
                else
                    bailout("Invalid type for StructLiteralExp: " ~ sle.toString);
            }
            else
            {
                bailout(elexpr.vType != BCValueType.Immediate, "When struct-literals are used as arguments all initializers, have to be immediates");
                if (elexpr.type.type.anyOf([BCTypeEnum.Slice, BCTypeEnum.Array, BCTypeEnum.Struct, BCTypeEnum.String]))
                {
                    immutable size_t targetAddr = structVal.imm32 + offset;
                    immutable size_t sourceAddr = elexpr.imm32;

                    if (targetAddr != sourceAddr)
                        _sharedCtfeState.heap._heap[targetAddr .. targetAddr + _size] = _sharedCtfeState.heap._heap[sourceAddr .. sourceAddr + _size];
                }
                else if (basicTypeSize(elexpr.type.type) == 8)
                {
                    _sharedCtfeState.heap._heap[structVal.imm32 + offset] = elexpr.imm64 & uint.max;
                    _sharedCtfeState.heap._heap[structVal.imm32 + offset + 4] = elexpr.imm64 >> 32;
                }
                else if (basicTypeSize(elexpr.type.type) && basicTypeSize(elexpr.type.type) <= 4)
                    _sharedCtfeState.heap._heap[structVal.imm32 + offset] = elexpr.imm32;
                else
                    bailout("Invalid type for StructLiteralExp: " ~ sle.toString);
            }

            offset += align4(_sharedCtfeState.size(elexpr.type, true));

        }

        retval = structVal;
    }

    override void visit(DollarExp de)
    {
        Line(de.loc.linnum);
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
        Line(ae.loc.linnum);
        //bailout("We don't handle AddrExp");
        auto e1 = genExpr(ae.e1, "AddrExp");
        // import std.stdio; writeln(ae.toString ~ " --  " ~ "e1: " ~ e1.toString); //debugline

        if (e1.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.i32, BCTypeEnum.i64]))
        {
            BCValue heapPtr = genTemporary(i32Type);
            Alloc(heapPtr, imm32(_sharedCtfeState.size(e1.type)));
            e1.heapRef = BCHeapRef(heapPtr);
            StoreToHeapRef(e1);
        }
        else if (e1.type.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.Array]))
        {
            // these are passed by pointer therefore their valuef is their heapRef
            e1.heapRef = BCHeapRef(e1);
        }
        else
        {
            bailout("We currently don't support taking the address of " ~ e1.type.toString ~ " -- " ~ ae.toString);
            return ;
        }

        assert(e1.heapRef, "AddrExp needs to be on the heap, otherwise is has no address");
        retval = BCValue(e1.heapRef).i32; // hack this is a ptr not an i32;
        // import std.stdio; writeln(ae.toString ~ " --  " ~ "retval: " ~ retval.toString); //debugline
        //assert(0, "Dieng on Addr ?");
    }

    override void visit(ThisExp te)
    {
        Line(te.loc.linnum);
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
        Line(ce.loc.linnum);
        Not(retval, genExpr(ce.e1));
    }

    override void visit(PtrExp pe)
    {
        Line(pe.loc.linnum);
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
        // has to be replaced by a genLoadForType() function that'll convert from
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
        Line(ne.loc.linnum);
        auto ptr = genTemporary(i32Type);
        auto type = toBCType(ne.newtype);
        auto typeSize = _sharedCtfeState.size(type);
        if (!isBasicBCType(type) || typeSize > 4)
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
        Line(ale.loc.linnum);
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
        debug(nullPtrCheck)
        {
            Comment("SetLengthNullPtrCheck");
            Assert(arr.i32, addError(Loc(), "setLength: arrPtr must not be null"));
        }
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
                // This should really never happen but ...
                // we seem to let a few slip trough
                if(!idx || idx > _sharedCtfeState.arrayCount)
                {
                    bailout("arrayIndex: " ~ to!string(idx) ~ " is out of bounds");
                    return BCValue.init;
                }
                length = imm32(_sharedCtfeState.arrayTypes[idx - 1].length);
            }
            else
            {
                if (insideArgumentProcessing)
                {
                    assert(arr.vType == BCValueType.Immediate);
                    if (arr.imm32)
                        length = imm32(_sharedCtfeState.heap._heap[arr.imm32 + SliceDescriptor.LengthOffset]);
                    else
                        length = imm32(0);
                }
                else
                {
                    length = genLocal(i32Type, "ArrayLength" ~ to!string(uniqueCounter++));
                    BCValue lengthPtr;
                    // if (arr is null) skip loading the length
                    auto CJskipLoad = beginCndJmp(arr.i32);
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
                    auto LAfterLoad = genLabel();
                    endCndJmp(CJskipLoad, LAfterLoad);
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
        Assert(arr.i32, addError(Loc(), "cannot set setBase of null array"));
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
            Assert(arr.i32, addError(Loc(), "cannot getBase from null array"));
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
                    Add3(baseAddrPtr, arr.i32, imm32(SliceDescriptor.BaseOffset));
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


    /// Params fIndex => fieldIndex of the field to be set to void/nonVoid
    /// Params nonVoid => true if seting to nonVoid false if setting to Void
    void setMemberVoidInit(BCValue structPtr, int fIndex, bool nonVoid)
    {
        assert(structPtr.type.type == BCTypeEnum.Struct, "setMemberVoidInit may only be called on structs for now");
        assert(structPtr.type.typeIndex, "StructPtr typeIndex invalid");
        auto structType = _sharedCtfeState.structTypes[structPtr.type.typeIndex - 1];

        auto bitfieldIndex = structType.voidInitBitfieldIndex(fIndex);

        BCValue bitFieldAddr  = genTemporary(i32Type);
        BCValue bitFieldValue = genTemporary(i32Type);
        Add3(bitFieldAddr, structPtr.i32, imm32(align4(structType.size) + StructMetaData.VoidInitBitfieldOffset));
        Load32(bitFieldValue, bitFieldAddr);
        uint bitFieldIndexBit = 1 << bitfieldIndex;
        if (nonVoid)
        {
            // set the bitfieldIndex Bit
            Or3(bitFieldValue, bitFieldValue, imm32(bitFieldIndexBit));
        }
        else
        {
            //unset the bitFieldIndex Bit
            And3(bitFieldValue, bitFieldValue, imm32(~bitFieldIndexBit));
        }

        Store32(bitFieldAddr, bitFieldValue);
    }

    BCValue getMemberVoidInit(BCValue structPtr, int fIndex)
    {
        assert(structPtr.type.type == BCTypeEnum.Struct, "setMemberVoidInit may only be called on structs for now");
        assert(structPtr.type.typeIndex, "StructPtr typeIndex invalid");
        auto structType = _sharedCtfeState.structTypes[structPtr.type.typeIndex - 1];

        auto bitfieldIndex = structType.voidInitBitfieldIndex(fIndex);

        BCValue bitFieldAddr  = genTemporary(i32Type);
        BCValue bitFieldValue = genTemporary(i32Type);
        Add3(bitFieldAddr, structPtr.i32, imm32(align4(structType.size) + StructMetaData.VoidInitBitfieldOffset));
        Load32(bitFieldValue, bitFieldAddr);

        And3(bitFieldValue, bitFieldValue, imm32(1 << bitfieldIndex));
        return bitFieldValue;
    }


    void LoadFromHeapRef(BCValue hrv, uint line = __LINE__)
    {
        // import std.stdio; writeln("Calling LoadHeapRef from: ", line); //DEBUGLINE
        if(hrv.type.type == BCTypeEnum.i64)
            Load64(hrv, BCValue(hrv.heapRef));
        else if (hrv.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.i32]))
            Load32(hrv, BCValue(hrv.heapRef));
        // since the stuff below are heapValues we may not want to do this ??
        else if (hrv.type.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.Slice, BCTypeEnum.Array]))
            MemCpy(hrv.i32, BCValue(hrv.heapRef).i32, imm32(_sharedCtfeState.size(hrv.type)));
        else
            bailout(to!string(hrv.type.type) ~ " is not supported in LoadFromHeapRef");

    }

    void StoreToHeapRef(BCValue hrv)
    {
        if(hrv.type.type == BCTypeEnum.i64)
            Store64(BCValue(hrv.heapRef), hrv);
        else if (hrv.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.i32]))
            Store32(BCValue(hrv.heapRef), hrv);
        // since the stuff below are heapValues we may not want to do this ??
        else if (hrv.type.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.Slice, BCTypeEnum.Array]))
            MemCpy(BCValue(hrv.heapRef).i32, hrv.i32, imm32(_sharedCtfeState.size(hrv.type)));
        else
            bailout(to!string(hrv.type.type) ~ " is not supported in StoreToHeapRef");
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
    void setArraySliceDesc(BCValue arr, BCArray arrayType)
    {
        //debug (NullAllocCheck)
        {
            Assert(arr.i32, addError(Loc(), "trying to set sliceDesc null Array"));
        }

        auto offset = genTemporary(i32Type);
        Add3(offset, arr.i32, imm32(SliceDescriptor.Size));

        setBase(arr.i32, offset);
        setLength(arr.i32, imm32(arrayType.length));
        auto et = arrayType.elementType;

        if (et.type == BCTypeEnum.Array)
        {
            assert(et.typeIndex);
            auto at = _sharedCtfeState.arrayTypes[et.typeIndex - 1];
            foreach(i;0 .. arrayType.length)
            {
                setArraySliceDesc(offset, at);
                Add3(offset, offset, imm32(_sharedCtfeState.size(et)));
            }
        }
    }

    /// Params: structPtr = assumed to point to already allocated Memory
    ///         type = a pointer to the BCStruct
    void initStruct(BCValue structPtr, const (BCStruct)* type)
    {
        /// TODO FIXME this has to copy the struct Intializers if there is one
        uint memberTypeCount = type.memberTypeCount;
        foreach(int i, mt; type.memberTypes[0 .. memberTypeCount])
        {
            if (mt.type == BCTypeEnum.Array)
            {
                auto offset = genTemporary(mt);
                Add3(offset.i32, structPtr.i32, imm32(type.offset(i)));
                setArraySliceDesc(offset, _sharedCtfeState.arrayTypes[mt.typeIndex - 1]);
            }
            if (mt.type == BCTypeEnum.Struct)
            {
                auto offset = genTemporary(mt);
                Add3(offset.i32, structPtr.i32, imm32(type.offset(i)));
                initStruct(offset, &_sharedCtfeState.structTypes[mt.typeIndex - 1]);
            }
        }
    }

    override void visit(VarExp ve)
    {
        Line(ve.loc.linnum);
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
        else if (ve.var.ident == Id.dollar)
        {
            retval = getLength(currentIndexed);
            return;
        }

        if (vd)
        {
            auto sv = getVariable(vd);
            debug (ctfe)
            {
                //assert(sv, "Variable " ~ ve.toString ~ " not in StackFrame");
            }

            if (sv.vType == BCValueType.VoidValue && !ignoreVoid)
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

            if (sv.heapRef != BCHeapRef.init && isStackValueOrParameter(sv))
            {
                LoadFromHeapRef(sv);
            }

            retval = sv;
        }
        else if (symd)
        {
            auto sd = symd.dsym;
            // import std.stdio; import ddmd.asttypename; writeln("Symbol variable exp: ", sd.astTypeName());//DEBUGLINE

            Expressions iexps;

            foreach (ie; *sd.members)
            {
                //iexps.push(new Expression();
            }
            auto sl = new StructLiteralExp(symd.loc, sd, &iexps);
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
        Line(de.loc.linnum);
        auto oldRetval = retval;
        auto vd = de.declaration.isVarDeclaration();

        if (!vd)
        {
            // It seems like we can ignore Declarartions which are not variables
            return;
        }

        visit(vd);
        auto var = retval;
        if (!var)
        {
            bailout("var for Declarartion could not be generated -- " ~ de.toString);
            return ;
        }
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
                else if (_init.type == BCType(BCTypeEnum.f23))
                {
                    Set(var.i32, _init.i32);
                }
                else if (_init.type.type == BCTypeEnum.Struct)
                {
                    //Set(var.i32, _init.i32);
                    //TODO we should really do a memcopy here instead of copying the pointer;
                    MemCpy(var.i32, _init.i32, imm32(_sharedCtfeState.size(_init.type)));
                }
                else if (_init.type.type == BCTypeEnum.Slice || _init.type.type == BCTypeEnum.Array || _init.type.type == BCTypeEnum.string8)
                {
                    // todo introduce a bool function passedByPtr(BCType t)
                    // maybe dangerous who knows ...
                    Set(var.i32, _init.i32);
                }
                else if (_init.type.type.anyOf([BCTypeEnum.c8, BCTypeEnum.i8, BCTypeEnum.i64]))
                {
                    Set(var.i32, _init.i32);
                }
                else if (_init.type.type == BCTypeEnum.Ptr && var.type.type == BCTypeEnum.Ptr)
                {
                    MemCpy(var.i32, _init.i32, imm32(SliceDescriptor.Size));
                    //Set(var.i32, _init.i32);
                }
                else
                {
                    bailout("We don't know howto deal with this initializer: " ~ _init.toString ~ " -- " ~ de.toString);
                }

            }
            retval = var;
        }
    }

    override void visit(VarDeclaration vd)
    {
        Line(vd.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("VarDeclaration %s discardValue %d", vd.toString, discardValue);
        }

        BCValue var;
        BCType type = toBCType(vd.type);
        if (!type)
        {
            bailout("could not get type for:" ~ vd.toString);
            return ;
        }
        bool refParam;
        if (processingParameters)
        {
            if (vd.storage_class & STCref)
            {
                type = i32Type;
            }

            var = genParameter(type, cast(string)vd.ident.toString);
            arguments ~= var;
            parameterTypes ~= type;
        }
        else
        {
            var = genLocal(type, cast(string)vd.ident.toString);
            if (type.type == BCTypeEnum.Slice || type.type == BCTypeEnum.string8)
            {
                Alloc(var.i32, imm32(SliceDescriptor.Size));
            }

           else if (type.type == BCTypeEnum.Array)
           {
                Alloc(var.i32, imm32(_sharedCtfeState.size(type)), type);
                assert(type.typeIndex);
                auto arrayType = _sharedCtfeState.arrayTypes[type.typeIndex - 1];
                setArraySliceDesc(var, arrayType);
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
        return ((lhs == BCTypeEnum.i32 || lhs == BCTypeEnum.f23 || lhs == BCTypeEnum.f52)
            && rhs == lhs) || lhs == BCTypeEnum.i64
            && (rhs == BCTypeEnum.i64 || rhs == BCTypeEnum.i32);
    }

    override void visit(BinAssignExp e)
    {
        Line(e.loc.linnum);
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

        if (e.op == TOKcatass && _sharedCtfeState.elementType(lhs.type) == _sharedCtfeState.elementType(rhs.type))
        {
            {
                if ((lhs.type.type == BCTypeEnum.Slice && lhs.type.typeIndex < _sharedCtfeState.sliceTypes.length) || lhs.type.type == BCTypeEnum.string8)
                {
                    if(!lhs.type.typeIndex && lhs.type.type != BCTypeEnum.string8)
                    {
                        bailout("lhs for ~= is no valid slice" ~ e.toString);
                        return ;
                    }
                    auto elementType = _sharedCtfeState.elementType(lhs.type);
                    retval = lhs;
                    doCat(lhs, lhs, rhs);
                }
                else
                {
                    bailout("Can only concat on slices or strings");
                    return;
                }
            }
        }
        else if (!canHandleBinExpTypes(lhs.type, rhs.type))
        {
            bailout("Cannot use binExpTypes: " ~ to!string(lhs.type.type) ~ " et: " ~ to!string(_sharedCtfeState.elementType(lhs.type))  ~ " -- " ~ "to!string(rhs.type.type)" ~ " et : " ~ to!string(_sharedCtfeState.elementType(rhs.type)) ~ " -- " ~ e.toString);
            return;
        }
        else switch (e.op)
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
        case TOK.TOKmodass:
            {
                Mod3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;

        default:
            {
                bailout("BinAssignExp Unsupported for now" ~ e.toString);
                return ;
            }
        }

        if (lhs.heapRef)
            StoreToHeapRef(lhs);

        if (oldAssignTo)
        {
            Set(oldAssignTo.i32, retval.i32);
            if (oldAssignTo.heapRef)
                StoreToHeapRef(oldAssignTo);
        }

       //assert(discardValue);

        retval = oldDiscardValue ? oldRetval : retval;
        discardValue = oldDiscardValue;
        assignTo = oldAssignTo;
    }

    override void visit(IntegerExp ie)
    {
        Line(ie.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("IntegerExpression %s", ie.toString);
        }

        auto bct = toBCType(ie.type);
        if (bct.type != BCTypeEnum.i32 && bct.type != BCTypeEnum.i64 && bct.type != BCTypeEnum.c8 &&
            bct.type != BCTypeEnum.c32 && bct.type != BCTypeEnum.i8)
        {
            //NOTE this can happen with cast(char*)size_t.max for example
            bailout("We don't support IntegerExpressions with non-integer types: " ~ to!string(bct.type));
        }

        if (bct.type == BCTypeEnum.i64)
        {
            retval = BCValue(Imm64(ie.value));
        }
        else
        {
            if (ie.type.ty == Tint32 && (cast(int) ie.value) < 0)
            {
                retval = BCValue(Imm64(cast(int)ie.value));
            }
            else
            {
                retval = imm32(cast(uint) ie.value);
            }
        }
        //auto value = evaluateUlong(ie);
        //retval = value <= int.max ? imm32(cast(uint) value) : BCValue(Imm64(value));
        assert(retval.vType == BCValueType.Immediate);
    }

    override void visit(RealExp re)
    {
        Line(re.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("RealExp %s", re.toString);
        }

        if (re.type.ty == Tfloat32)
        {
            float tmp = cast(float)re.value;
            retval = imm32(*cast(uint*)&tmp);
            retval.type.type = BCTypeEnum.f23;
        }
        else if (re.type.ty == Tfloat64)
        {
            double tmp = cast(double)re.value;
            retval = BCValue(Imm64(*cast(ulong*)&tmp));
            retval.type.type = BCTypeEnum.f52;
        }
        else
            bailout("RealExp unsupported");
    }

    override void visit(ComplexExp ce)
    {
        Line(ce.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ComplexExp %s", ce.toString);
        }

        bailout("ComplexExp unspported");
    }

    override void visit(StringExp se)
    {
        Line(se.loc.linnum);
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
        BCValue stringAddr = imm32(heap.heapSize);
        uint heapAdd = SliceDescriptor.Size;

        // always reserve space for the slice;
        heapAdd += length * sz;
        heapAdd = align4(heapAdd);

        bailout(heap.heapSize + heapAdd > heap.heapMax, "heapMax exceeded while pushing: " ~ se.toString);
        _sharedCtfeState.heap.heapSize += heapAdd;

        auto baseAddr = stringAddr.imm32 + SliceDescriptor.Size;
        // first set length
        if (length)
        {
            _sharedCtfeState.heap._heap[stringAddr.imm32 + SliceDescriptor.LengthOffset] = length;
            // then set base
            _sharedCtfeState.heap._heap[stringAddr.imm32 + SliceDescriptor.BaseOffset] = baseAddr;
        }

        uint offset = baseAddr;
        switch(sz)
        {
            case 1 : foreach(c;se.string[0 .. length])
            {
                _sharedCtfeState.heap._heap[offset++] = c;
            }
            break;
            default : bailout("char_size: " ~ to!string(sz) ~" unsupported");
        }

        stringAddr.type = BCType(BCTypeEnum.string8);

        if (insideArgumentProcessing)
        {
            retval = stringAddr;
        }
        else
        {
            retval = assignTo ? assignTo : genTemporary(BCType(BCTypeEnum.String));
            Set(retval.i32, stringAddr.i32);
        }
    }

    override void visit(CmpExp ce)
    {
        Line(ce.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("CmpExp %s discardValue %d", ce.toString, discardValue);
        }
        auto oldAssignTo = assignTo ? assignTo : genTemporary(i32Type);
        assignTo = BCValue.init;
        auto lhs = genExpr(ce.e1);
        auto rhs = genExpr(ce.e2);
        if (!lhs || !rhs)
        {
            bailout("could not gen lhs or rhs in: " ~ ce.toString);
            return ;
        }

        if (lhs.type.type == BCTypeEnum.Ptr || rhs.type.type == BCTypeEnum.Ptr)
        {
            bailout("Currently we don't support < or > for pointers.");
            return ;
        }
        if (canWorkWithType(lhs.type) && canWorkWithType(rhs.type) && (!oldAssignTo || canWorkWithType(oldAssignTo.type)) || true)
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
                rhs.type.type) ~ " result: " ~ to!string(oldAssignTo.type.type) ~ " -- " ~  ce.toString);
        }
    }

    static bool canWorkWithType(const BCType bct) pure
    {
        return (bct.type.anyOf([BCTypeEnum.i8, BCTypeEnum.i32, BCTypeEnum.i64, BCTypeEnum.f23, BCTypeEnum.f52]));
    }
/+
    override void visit(ConstructExp ce)
    {
        Line(ce.loc.linnum);
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
+/

    override void visit(AssignExp ae)
    {
        Line(ae.loc.linnum);
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
            SliceExp e1 = cast(SliceExp)ae.e1;
            SliceExp e2 = cast(SliceExp)ae.e2;

            auto lhs = genExpr(e1);
            auto rhs = genExpr(e2);

            auto lhs_base = getBase(lhs);
            auto rhs_base = getBase(rhs);

            auto lhs_length = getLength(lhs);
            auto rhs_length = getLength(rhs);

            auto lhs_lwr = (!e1.lwr) ? imm32(0) : genExpr(e1.lwr);
            auto rhs_lwr = (!e2.lwr) ? imm32(0) : genExpr(e2.lwr);
            auto lhs_upr = (!e1.upr) ? lhs_length : genExpr(e1.upr);
            auto rhs_upr = (!e2.upr) ? rhs_length : genExpr(e2.upr);

            if (!rhs || !lhs || !lhs_length || !rhs_length)
            {
                bailout("SliceAssign could not be generated: " ~ ae.toString);
                return ;
            }

            {
                Neq3(BCValue.init, lhs_length, rhs_length);
                auto CJLengthUnequal = beginCndJmp();

                Assert(imm32(0), addError(ae.loc, "array length mismatch assigning [%d..%d] to [%d..%d]", rhs_lwr, rhs_upr, lhs_lwr, lhs_upr));
                endCndJmp(CJLengthUnequal, genLabel());
            }

            auto elemSize = sharedCtfeState.size(sharedCtfeState.elementType(lhs.type));

            if (!elemSize)
            {
                bailout("could not get elementSize of : " ~ _sharedCtfeState.typeToString(lhs.type));
                return ;
            }


            {
                auto overlapError = addError(ae.loc, "overlapping slice assignment [%d..%d] = [%d..%d]", lhs_lwr, lhs_upr, rhs_lwr, rhs_upr);

                // const diff = ptr1 > ptr2 ? ptr1 - ptr2 : ptr2 - ptr1;
                auto diff = genTemporary(i32Type);
                {
                    auto lhs_gt_rhs = genTemporary(i32Type);
                    Gt3(lhs_gt_rhs, lhs_base, rhs_base);

                    auto cndJmp1 = beginCndJmp(lhs_gt_rhs);// ---\
                        Sub3(diff, lhs_base, rhs_base);//        |
                        auto to_end = beginJmp();// ------\      |
                    endCndJmp(cndJmp1, genLabel());// <---+------/
                        Sub3(diff, rhs_base, lhs_base);// |
                    endJmp(to_end, genLabel());//  <------/
                }

                // if(d < length) assert(0, overlapError);
                {
                    auto scaled_length = genTemporary(i32Type);
                    auto diff_lt_scaled = genTemporary(i32Type);
                    Mul3(scaled_length, lhs_length, imm32(elemSize));
                    Lt3(diff_lt_scaled, diff, scaled_length);
                    auto cndJmp1 = beginCndJmp(diff_lt_scaled);
                        Assert(imm32(0), overlapError);
                    endCndJmp(cndJmp1, genLabel());
                }
            }

            copyArray(&lhs_base, &rhs_base, lhs_length, elemSize);
        }

        debug (ctfe)
        {
            import std.stdio;
            writeln("OP: ", ae.op.to!string);
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
            auto bcStructType = _sharedCtfeState.structTypes[structTypeIndex - 1];
            auto fieldType = bcStructType.memberTypes[fIndex];
            // import std.stdio; writeln("got fieldType: ", fieldType); //DEBUGLINE

            static immutable supportedStructTypes =
            () {
                with(BCTypeEnum)
                {
                    return [i8, i32, i64, f23, f52];
                }
            } ();


            if (!fieldType.type.anyOf(supportedStructTypes))
            {
                bailout("only " ~ to!string(supportedStructTypes) ~ " are supported for structs (for now) ... not : " ~ to!string(bcStructType.memberTypes[fIndex].type));
                return;
            }

            auto lhs = genExpr(_struct);
            if (!lhs)
            {
                bailout("could not gen: " ~ _struct.toString);
                return ;
            }

            auto rhs = genExpr(ae.e2);
            if (!rhs)
            {
                //Not sure if this is really correct :)
                rhs = bcNull;
            }

            {
                if (bcStructType.voidInit[fIndex])
                {
                    // set member to be inited.
                    setMemberVoidInit(lhs, fIndex, true);
                }
            }

            if (!rhs.type.type.anyOf(supportedStructTypes))
            {
                bailout("only " ~ to!string(supportedStructTypes) ~ " are supported for now. not:" ~ rhs.type.type.to!string);
                return;
            }


            auto ptr = genTemporary(BCType(BCTypeEnum.i32));

            Add3(ptr, lhs.i32, imm32(bcStructType.offset(fIndex)));
            immutable size = _sharedCtfeState.size(rhs.type);
            if (size && size <= 4)
                Store32(ptr, rhs);
            else if (size == 8)
                Store64(ptr, rhs);
            else
                bailout("only sizes [1 .. 4], and 8  are supported. MemberSize: " ~ to!string(size));


            retval = rhs;
        }
        else if (ae.e1.op == TOKarraylength)
        {
            auto ale = cast(ArrayLengthExp) ae.e1;

            // We are assigning to an arrayLength
            // This means possibly allocation and copying
            auto arrayPtr = genExpr(ale.e1, "ArrayExpansion Slice");
            if (!arrayPtr)
            {
                bailout("I don't have an array to load the length from :(");
                return;
            }

            if (arrayPtr.type != BCTypeEnum.Slice && arrayPtr.type != BCTypeEnum.string8)
            {
                bailout("can only assign to slices and not to " ~to!string(arrayPtr.type.type));
            }

            BCValue oldLength = getLength(arrayPtr);
            BCValue newLength = genExpr(ae.e2, "ArrayExpansion newLength");
            expandSliceTo(arrayPtr, newLength);
        }
        else if (ae.e1.op == TOKindex)
        {
            auto ie1 = cast(IndexExp) ae.e1;

            auto indexed = genExpr(ie1.e1, "AssignExp.e1(indexExp).e1 (e1[x])");
            if (!indexed)
            {
                bailout("could not fetch indexed_var in " ~ ae.toString);
                return;
            }
            auto index = genExpr(ie1.e2, "AssignExp.e1(indexExp).e2: (x[e2])");
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
                auto v = genTemporary(i32Type);
                Lt3(v, index, length);
                Assert(v, addError(ae.loc,
                    "ArrayIndex %d out of bounds %d", index, length));
            }
            auto effectiveAddr = genTemporary(i32Type);
            auto elemType = toBCType(ie1.e1.type.nextOf);
            auto elemSize = _sharedCtfeState.size(elemType);

            Mul3(effectiveAddr, index, imm32(elemSize));
            Add3(effectiveAddr, effectiveAddr, baseAddr);
            if (elemSize > 4 && elemSize != 8)
            {
                bailout("only 32/64 bit array loads are supported right now");
            }

            auto rhs = genExpr(ae.e2);
            if (!rhs)
            {
                bailout("we could not gen AssignExp[].rhs: " ~ ae.e2.toString);
                return ;
            }
/*

            auto elemType = toBCType(ie1.e1.type.nextOf);
            auto elemSize = _sharedCtfeState.size(elemType);

            ignoreVoid = true;
            auto lhs = genExpr(ie1);
            ignoreVoid = false;

            auto rhs = genExpr(ae.e2);
            if (!lhs || !rhs)
            {
                bailout("could not gen lhs or rhs of AssignExp: " ~ ae.toString);
                return ;
            }
            if (!lhs.heapRef)
            {
                bailout("lhs for Assign-IndexExp needs to have a heapRef: " ~ ae.toString);
                return ;
            }
            auto effectiveAddr = BCValue(lhs.heapRef);
*/
            if (rhs.type.type.anyOf([BCTypeEnum.Array, BCTypeEnum.Struct, BCTypeEnum.Slice]))
            {
                MemCpy(effectiveAddr.i32, rhs.i32, imm32(sharedCtfeState.size(rhs.type)));
            }
            else if (elemSize && elemSize <= 4)
                Store32(effectiveAddr, rhs.i32);
            else if (elemSize == 8)
                Store64(effectiveAddr, rhs);
            else
               bailout("cannot deal with this store");

        }
        else
        {
            ignoreVoid = true;
            auto lhs = genExpr(ae.e1, "AssignExp.lhs");
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
            auto rhs = genExpr(ae.e2, "AssignExp.rhs");

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
            else if (lhs.type.type == BCTypeEnum.f23 && rhs.type.type == BCTypeEnum.f23)
            {
                Set(lhs, rhs);
            }
            else if (lhs.type.type == BCTypeEnum.f52 && rhs.type.type == BCTypeEnum.f52)
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
                        MemCpy(lhs.i32, rhs.i32, imm32(SliceDescriptor.Size));
                    }
                    else
                    {
                        bailout(ptrType.elementType != rhs.type, "unequal types for *lhs and rhs: " ~ _sharedCtfeState.typeToString(lhs.type) ~" -- " ~ _sharedCtfeState.typeToString(rhs.type));
                        if (basicTypeSize(rhs.type.type) && basicTypeSize(rhs.type.type) <= 4) Store32(lhs, rhs);
                        else bailout("Storing to ptr which is not i8 or i32 is unsupported for now");
                     }
                }
                else if (lhs.type.type == BCTypeEnum.Struct && lhs.type == rhs.type)
                {
                    auto size = _sharedCtfeState.size(lhs.type).align4;
                    if (size)
                    {
                        auto sizeImm32 = imm32(size);

                        if (ae.op == TOKconstruct)
                        {
                            auto CJLhsIsNull = beginCndJmp(lhs.i32, true);
                            Alloc(lhs.i32, sizeImm32);
                            endCndJmp(CJLhsIsNull, genLabel());
                        }
                    

                        MemCpy(lhs.i32, rhs.i32, sizeImm32);
                    }
                    else
                        bailout("0-sized allocation in: " ~ ae.toString);
                }
                else if (lhs.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.c8]) && rhs.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.c8]))
                {
                    Set(lhs.i32, rhs.i32);
                }
                else if ((lhs.type.type == BCTypeEnum.String && rhs.type.type == BCTypeEnum.String) ||
                    (lhs.type.type == BCTypeEnum.Slice && rhs.type.type == BCTypeEnum.Array) ||
                    (lhs.type.type == BCTypeEnum.Slice && rhs.type.type == BCTypeEnum.Slice))
                {
                    if (ae.op == TOKconstruct)
                    {
                        auto CJLhsIsNull = beginCndJmp(lhs.i32, true);
                        Alloc(lhs.i32, imm32(SliceDescriptor.Size));
                        endCndJmp(CJLhsIsNull, genLabel());
                    }

                    MemCpy(lhs.i32, rhs.i32, imm32(SliceDescriptor.Size));
                }
                else if (lhs.type.type == BCTypeEnum.Array && rhs.type.type == BCTypeEnum.Array)
                {
                    auto lhsBase = getBase(lhs);
                    auto rhsBase = getBase(rhs);
                    auto lhsLength = getLength(lhs);
                    auto rhsLength = getLength(lhs);
                    auto sameLength = genTemporary(i32Type);
                    auto lhsBaseType = _sharedCtfeState.elementType(lhs.type);

                    Eq3(sameLength, lhsLength, rhsLength);
                    Assert(sameLength, addError(ae.loc, "%d != %d", rhsLength, lhsLength));

                    copyArray(&lhsBase, &rhsBase, lhsLength, _sharedCtfeState.size(lhsBaseType));
                }
                else if ((lhs.type.type == BCTypeEnum.Slice || lhs.type.type == BCTypeEnum.String) && rhs.type.type == BCTypeEnum.Null)
                {
                    Alloc(lhs.i32, imm32(SliceDescriptor.Size));
                }
                else if (lhs.type.type == BCTypeEnum.Array)
                {
                    assert(lhs.type.typeIndex, "Invalid arrayTypes as lhs of: " ~ ae.toString);
                    immutable arrayType = _sharedCtfeState.arrayTypes[lhs.type.typeIndex - 1];
                    Alloc(lhs.i32, imm32(_sharedCtfeState.size(lhs.type)), lhs.type);
                    Comment("setArraySliceDesc for: " ~ _sharedCtfeState.typeToString(lhs.type));
                    setArraySliceDesc(lhs, arrayType);
                    setLength(lhs.i32, imm32(arrayType.length));
                    auto base = getBase(lhs);
                    if (rhs.type.type.anyOf([BCTypeEnum.i32, BCTypeEnum.i64]) && rhs.vType == BCValueType.Immediate && rhs.imm32 == 0)
                    {
                        // no need to do anything ... the heap is supposed to be zero
                    }
                    else if (rhs.type == arrayType.elementType)
                    {
                        bailout("broadcast assignment not supported for now -- " ~ ae.toString);
                        return ;
                    }
                    else
                    {
                        bailout("ArrayAssignment unhandled: " ~ ae.toString);
                        return ;
                    }
                }
                else if (lhs.type.type == BCTypeEnum.Struct && rhs.type.type == BCTypeEnum.i32 && rhs.imm32 == 0)
                {
                    Comment("Struct == 0");
                    if(!lhs.type.typeIndex || lhs.type.typeIndex > _sharedCtfeState.structCount)
                    {
                        bailout("Struct Type is invalid: " ~ ae.e1.toString);
                        return ;
                    }
                    if (!_sharedCtfeState.size(lhs.type))
                    {
                        bailout("StructType has invalidSize (this is really bad): " ~ ae.e1.toString);
                        return ;
                    }
                    const structType = &_sharedCtfeState.structTypes[lhs.type.typeIndex - 1];

                    // HACK allocate space for struct if structPtr is zero
                    auto structZeroJmp = beginCndJmp(lhs.i32, true);
                    auto structSize = _sharedCtfeState.size(lhs.type);
                    Alloc(lhs.i32, imm32(structType.size), lhs.type);

                    initStruct(lhs, structType);

                    endCndJmp(structZeroJmp, genLabel());
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
        retval = assignTo;

        assignTo = oldAssignTo;
        discardValue = oldDiscardValue;

    }

    override void visit(SwitchErrorStatement _)
    {
        Line(_.loc.linnum);
        //assert(0, "encounterd SwitchErrorStatement" ~ toString(_));
    }

    override void visit(NegExp ne)
    {
        Line(ne.loc.linnum);
        retval = assignTo ? assignTo : genTemporary(toBCType(ne.type));
        Sub3(retval, imm32(0), genExpr(ne.e1));
    }

    override void visit(NotExp ne)
    {
        Line(ne.loc.linnum);
        {
            retval = assignTo ? assignTo : genTemporary(i32Type);
            Eq3(retval, genExpr(ne.e1).i32, imm32(0));
        }

    }

    override void visit(UnrolledLoopStatement uls)
    {
        Line(uls.loc.linnum);
        //FIXME This will break if UnrolledLoopStatements are nested,
        // I am not sure if this can ever happen
        if (unrolledLoopState)
        {
        //TODO this triggers in vibe.d however it still passes the tests ...
        //We need to fix this properly at some point!
            bailout("unrolled loops may not be nested");
        }
        auto _uls = UnrolledLoopState();
        unrolledLoopState = &_uls;
        uint end = cast(uint) uls.statements.dim - 1;

        foreach (stmt; *uls.statements)
        {
            auto block = genBlock(stmt, true, true);

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

        }

        auto afterUnrolledLoop = genLabel();
        {
            //FIXME Be aware that a break fixup has to be checked aginst the ip
            //If there if an unrolledLoopStatement that has no statemetns in it,
            // we end up fixing the jump up to ourselfs.
            foreach (fixup; _uls.breakFixups[0 .. _uls.breakFixupCount])
            {
                //HACK the will leave a nop in the bcgen
                //but it will break llvm or other potential backends;
                Comment("Putting unrolled_loopStatement-breakFixup");
                if (fixup.addr != afterUnrolledLoop.addr)
                    endJmp(fixup, afterUnrolledLoop);

            }
            _uls.breakFixupCount = 0;
        }


        unrolledLoopState = null;
    }

    override void visit(ImportStatement _is)
    {
        Line(_is.loc.linnum);
        // can be skipped
        return;
    }

    override void visit(AssertExp ae)
    {
        Line(ae.loc.linnum);

        if (isBoolExp(ae.e1))
        {
            bailout("asserts on boolean expression currently unsupported");
            return ;
        }

        auto lhs = genExpr(ae.e1, "AssertExp.e1");
        if (lhs.type.type == BCTypeEnum.i32 || lhs.type.type == BCTypeEnum.Ptr || lhs.type.type == BCTypeEnum.Struct)
        {
            Assert(lhs.i32, addError(ae.loc,
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
        Line(ss.loc.linnum);
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

            foreach (int i, caseStmt; *(ss.cases))
            {
                switchFixup = &switchFixupTable[switchFixupTableCount];
                caseStmt.index = i;
                // apperantly I have to set the index myself;

                auto rhs = genExpr(caseStmt.exp);
                stringSwitch ? StringEq(BCValue.init, lhs, rhs) : Eq3(BCValue.init,
                    lhs, rhs);
                auto jump = beginCndJmp();
                if (caseStmt.statement)
                {
                    import ddmd.blockexit;
                    auto blockExitResult = caseStmt.statement.blockExit(me, false);
                    bool blockReturns = !!(blockExitResult & (BEany & ~BEfallthru));
                    bool falltrough = !!(blockExitResult & BEfallthru);

                    auto caseBlock = genBlock(caseStmt.statement);
                    beginCaseStatements[beginCaseStatementsCount++] = caseBlock.begin;
                    //If the block returns regardless there is no need for a fixup
                    if (!blockReturns)
                    {
                        assert(!falltrough || i < ss.cases.dim); // hope this works :)

                        switchFixupTable[switchFixupTableCount++] = SwitchFixupEntry(beginJmp(), falltrough ? i + 2 : 0);
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
        Line(gcs.loc.linnum);
        with (switchState)
        {
            *switchFixup = SwitchFixupEntry(beginJmp(), gcs.cs.index + 1);
            switchFixupTableCount++;
        }
    }

    override void visit(GotoDefaultStatement gd)
    {
        Line(gd.loc.linnum);
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
        Line(gs.loc.linnum);
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
        Line(ls.loc.linnum);
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
        Line(cs.loc.linnum);
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
        Line(bs.loc.linnum);
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
        Line(ce.loc.linnum);
        bool wrappingCallFn;
        if (!insideFunction)
        {
            // bailout("We cannot have calls outside of functions");
            // We are not inside a function body hence we are expected to return the result of this call
            // for that to work we construct a function which will look like this { return fn(); }
            beginFunction(_sharedCtfeState.functionCount++);
            retval = genTemporary(i32Type);
            insideFunction = true;
            wrappingCallFn = true;
        }
        BCValue thisPtr;
        BCValue fnValue;
        FuncDeclaration fd;
        bool isFunctionPtr;

        //NOTE is could also be Tdelegate


        if (!ce.e1 || !ce.e1.type)
        {
            bailout("either ce.e1 or ce.e1.type is null: " ~ ce.toString);
            return ;
        }

        TypeFunction tf;
        if(ce.e1.type.ty == Tfunction)
        {
            tf = cast (TypeFunction) ce.e1.type;
        }
        else if (ce.e1.type.ty == Tdelegate)
        {
            tf = cast (TypeFunction) ((cast(TypeDelegate) ce.e1.type).nextOf);
        }
        else
        {
            bailout("CallExp.e1.type.ty expected to be Tfunction, but got: " ~ to!string(cast(ENUMTY) ce.e1.type.ty));
            return ;
        }
        TypeDelegate td = cast (TypeDelegate) ce.e1.type;
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
        // functionPtr
        else if (ce.e1.op == TOKstar)
        {
            isFunctionPtr = true;
            fnValue = genExpr(ce.e1);
        }
        // functionLiteral
        else if (ce.e1.op == TOKfunction)
        {
            //auto fnValue = genExpr(ce.e1);
            fd = (cast(FuncExp)ce.e1).fd;
        }

        if (!isFunctionPtr)
        {
            if (!fd)
            {
                bailout("could not get funcDecl -- " ~ astTypeName(ce.e1) ~ " -- toK :" ~ to!string(ce.e1.op) );
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
        uint lastArgIndx = cast(uint)ce.arguments.dim;//cast(uint)(ce.arguments.dim > nParameters ? ce.arguments.dim : nParameters);
        bc_args.length = lastArgIndx + !!(thisPtr);

        foreach (i, arg; *ce.arguments)
        {
            bc_args[i] = genExpr(arg, "CallExpssion Argument");
            if (bc_args[i].vType == BCValueType.Unknown)
            {
                bailout(arg.toString ~ "did not evaluate to a valid argument");
                return ;
            }
            if (bc_args[i].type == BCTypeEnum.i64)
            {
                if (!is(BCGen) && !is(Print_BCGen))
                {
                    bailout(arg.toString ~ "cannot safely pass 64bit arguments yet");
                    return ;
                }
            }

            if ((*tf.parameters)[i].storageClass & STCref)
            {
                auto argHeapRef = genTemporary(i32Type);
                auto origArg = bc_args[i];
                auto size = _sharedCtfeState.size(origArg.type);
                if (!size)
                {
                    bailout("arg with no size -- " ~ arg.toString);
                    return ;
                }
                Alloc(argHeapRef, imm32(size));
                bc_args[i].heapRef = BCHeapRef(argHeapRef);
                StoreToHeapRef(bc_args[i]);
                bc_args[i] = argHeapRef;
            }
        }

        //put in the default args
        foreach(dai;ce.arguments.dim .. nParameters)
        {
            auto defaultArg = (*tf.parameters)[dai].defaultArg;
            Comment("Doing defaultArg " ~ to!string(dai - ce.arguments.dim));
            //bc_args[dai] = genExpr(defaultArg);
        }
        if (thisPtr)
        {
            bc_args[lastArgIndx] = thisPtr;
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
                    if (!origArg)
                    {
                        bailout("could not generate origArg[" ~ to!string(i) ~ "] for ref in: " ~ ce.toString);
                        return ;
                    }
                    origArg.heapRef = BCHeapRef(arg);
                    LoadFromHeapRef(origArg);
              }
            }

            import ddmd.identifier;
            /*if (fd.ident == Identifier.idPool("isGraphical"))
            {                import std.stdio;
                writeln("igArgs :", bc_args);
            }*/
        }
        else
        {
            bailout("Functions are unsupported by backend " ~ BCGenT.stringof);
        }

        if (wrappingCallFn)
        {
            Ret(retval);
            endFunction();
            insideFunction = false;
        }
        return;

    }

    override void visit(ReturnStatement rs)
    {
        Line(rs.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ReturnStatement %s", rs.toString);
        }
        assert(!inReturnStatement);
        assert(!discardValue, "A returnStatement cannot be in discarding Mode");
        if (rs.exp !is null)
        {
            auto retval = genExpr(rs.exp, "ReturnStatement");
            if (!retval)
            {
                bailout("could not gen returnValue: " ~ rs.exp.toString);
                return ;
            }
            static immutable acceptedReturnTypes =
            () {
                with (BCTypeEnum)
                {
                    return [c8, i8, c32, i32, i64, f23, f52, Slice, Array, Struct, string8];
                }
            } ();

            if (retval.type.type.anyOf(acceptedReturnTypes))
                Ret(retval);
            else
            {
                bailout(
                    "could not handle returnStatement with BCType " ~ to!string(retval.type.type));
                return;
            }
        }
        else
        {
            // rs.exp is null for  "return ";
            // return ; is only legal when the return type is void
            // so we can return a bcNull without fearing consequnces;

            Ret(bcNull);
        }

    }

    override void visit(CastExp ce)
    {
        Line(ce.loc.linnum);
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

        retval = genExpr(ce.e1, "CastExp.e1");
        if (toType == fromType)
        {
            //newCTFE does not need to cast
        }
        else if (toType.type == BCTypeEnum.Ptr)
        {
            if (fromType.type == BCTypeEnum.Slice &&
                _sharedCtfeState.elementType(fromType) == _sharedCtfeState.elementType(toType))
            {
                // do nothing pointer have the same abi as slices :)
                // HACK FIXME this might not be actaully the case
                retval.type = toType;
            }
            else
            {
                bailout("We cannot cast pointers");
            }


            return ;
        }
        else if (fromType.type == BCTypeEnum.c32)
        {
            if (toType.type != BCTypeEnum.i32 && toType.type != BCTypeEnum.i64)
                bailout("CastExp unsupported: " ~ ce.toString);
        }
        else if (fromType.type == BCTypeEnum.i8 || fromType.type == BCTypeEnum.c8)
        {
            // a "bitcast" is enough all implentation are assumed to use 32/64bit registers
            if (toType.type.anyOf([BCTypeEnum.i8, BCTypeEnum.c8, BCTypeEnum.i32, BCTypeEnum.i16, BCTypeEnum.i64]))
                retval.type = toType;
            else
            {
                bailout("Cannot do cast toType:" ~ to!string(toType.type) ~ " -- "~ ce.toString);
                return ;
            }
        }
        else if (fromType.type == BCTypeEnum.i32 || fromType.type == BCTypeEnum.i64)
        {
            if (toType.type == BCTypeEnum.f23)
            {
                const from = retval;
                retval = genTemporary(BCType(BCTypeEnum.f23));
                IToF32(retval, from);
            }
            else if (toType.type == BCTypeEnum.f52)
            {
                const from = retval;
                retval = genTemporary(BCType(BCTypeEnum.f52));
                IToF64(retval, from);
            }
            else if (toType == BCTypeEnum.i32) {} // nop
            else if (toType == BCTypeEnum.i64) {} // nop
            else if (toType.type.anyOf([BCTypeEnum.c8, BCTypeEnum.i8]))
                And3(retval.i32, retval.i32, imm32(0xff));
            else
            {
                bailout("Cast not implemented: " ~ ce.toString);
                return ;
            }
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
        else if (fromType.type == BCTypeEnum.string8
                && toType.type == BCTypeEnum.Slice && toType.typeIndex
                && _sharedCtfeState.sliceTypes[toType.typeIndex - 1].elementType.type
                == BCTypeEnum.i8)
        {
            // for the cast(ubyte[])string case
            // for now make an i8 slice
            _sharedCtfeState.sliceTypes[_sharedCtfeState.sliceCount++] = BCSlice(BCType(BCTypeEnum.i8));
            retval.type = toType;
        }
        else if (toType.type == BCTypeEnum.string8
                && fromType.type == BCTypeEnum.Slice && fromType.typeIndex
                && _sharedCtfeState.sliceTypes[fromType.typeIndex - 1].elementType.type
                == BCTypeEnum.i8)
        {
            // for the cast(ubyte[])string case
            // for now make an i8 slice
            _sharedCtfeState.sliceTypes[_sharedCtfeState.sliceCount++] = BCSlice(BCType(BCTypeEnum.i8));
            retval.type = BCType(BCTypeEnum.Slice, _sharedCtfeState.sliceCount);
            //retval.type = toType;
        }
        else
        {
            bailout("CastExp unsupported:  " ~ ce.toString ~ " toType: " ~ _sharedCtfeState.typeToString(toType) ~ " fromType: " ~ _sharedCtfeState.typeToString(fromType)) ;
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
        Line(es.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ExpStatement %s", es.toString);
        }
        immutable oldDiscardValue = discardValue;
        discardValue = true;
        if (es.exp)
            genExpr(es.exp, "ExpStatement");
        discardValue = oldDiscardValue;
    }

    override void visit(DoStatement ds)
    {
        Line(ds.loc.linnum);
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
        //Line(ws.loc.linnum);

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
        Line(s.loc.linnum);
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
        Line(fs.loc.linnum);
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
        bool boolExp = isBoolExp(fs.condition);

        if (boolExp)
        {
            boolres = genTemporary(i32Type);
        }

        auto cond = genExpr(fs.condition, false);

        if (!cond)
        {
            bailout("IfStatement: Could not genrate condition" ~ fs.condition.toString);
            return;
        }

        typeof(beginCndJmp(cond)) cj;
        typeof(beginJmp()) j;

        if (!boolExp)
            cj = beginCndJmp(cond.i32);
        else
            cj = beginCndJmp(boolres);

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
        Line(ss.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ScopeStatement %s", ss.toString);
        }
        ss.statement.accept(this);
    }

    override void visit(CompoundStatement cs)
    {
        Line(cs.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("CompundStatement %s", cs.toString);
        }

        if (cs.statements !is null)
        {
            foreach (stmt; (*cs.statements))
            {
                // null statements can happen in here
                // but it seems there is no harm in ignoring them

                if (stmt !is null)
                {
                    stmt.accept(this);
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

