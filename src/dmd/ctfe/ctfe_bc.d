module dmd.ctfe.ctfe_bc;
import dmd.ctfe.bc_limits;
import dmd.expression;
import dmd.declaration;
import dmd.dsymbol;
import dmd.dstruct;
import dmd.dscope;
import dmd.dclass;
import dmd.func;
import dmd.init;
import dmd.mtype;
import dmd.statement;
import dmd.sideeffect;
import dmd.tokens;
import dmd.visitor;
import dmd.arraytypes : Expressions, VarDeclarations, Catches;
import dmd.root.rmem;
import dmd.astenums;
import dmd.dinterpret;
/**
 * Written By Stefan Koch in 2016-21
 */

import core.stdc.stdio : printf;
import std.string : fromStringz;

enum perf = 0;
enum bailoutMessages = 1;
enum printResult = 0;
enum cacheBC = 1;
enum UseLLVMBackend = 0;
enum UsePrinterBackend = 0;
enum UseCBackend = 0;
enum UseGCCJITBackend = 0;
enum abortOnCritical = 1;
enum state_logging = 0;

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

enum GenExprFlags
{
    None,
    customBoolFixup = 0x1,
    asAddress = 0x2,
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

struct UncompiledCatches
{
   Catches* catches;
   uint fnIdx;
}

struct UncompiledFunction
{
    FuncDeclaration fd;
    uint fn;
    bool mayFail; /** virtual functions may fail
                      to complile for ctfe this is
                      okay since we can not statically
                      proof if it is actually called */
    string dummyErrorFunctionMessage = null;
}

struct UncompiledConstructor
{
    /// may be null. if so use type.typeIndex
    /// to get the ClassDeclPtr
    CtorDeclaration cd;
    BCType type;
    int fnIdx;
}

struct UncompiledDynamicCast
{
    BCType toType;
    int fnIdx;
}

struct SwitchFixupEntry
{
    BCAddr atIp;
    alias atIp this;
    /// 0 means jump after the switch
    /// -1 means jump to the defaultStmt
    /// positive numbers denote which case to jump to
    int fixupFor;
}

struct BoolExprFixupEntry
{
    CndJmpBegin conditional;

    this(CndJmpBegin conditional) pure
    {
        this.conditional = conditional;
    }
}

struct FieldInfo
{
    int offset = -1;
    int index = -1;
    BCType type = BCType.init;
}

struct UnrolledLoopState
{
    BCAddr[255] continueFixups;
    uint continueFixupCount;

    BCAddr[255] breakFixups;
    uint breakFixupCount;
}

struct UnrolledLoopStack
{
    UnrolledLoopState[1024] loops;
    uint unrolledLoopCount;

    UnrolledLoopState* push() return
    {
        return &loops[unrolledLoopCount++];
    }

    UnrolledLoopState* pop()
    {
        UnrolledLoopState* result = null;
        if (unrolledLoopCount)
        {
            result = &loops[--unrolledLoopCount];
        }
        return result;
    }
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
    import dmd.identifier : Identifier;

    bool isInitialized() pure const
    {
        return list[0]!is Identifier.init;
    }

    Identifier[32] list;

    void initialize(string[] blacklistNames)
    {
        if (isInitialized)
            return ;

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
                "grisu2", // because it does not work yet ... 
                "modify14304", //because of fail_compilation/fail14304.d; We should not be required to check for this.
                "bug2931", //temporarily to pass a test for multi-dimensional arrays
                "bug2931_2", //temporarily to pass a test for multi-dimensional arrays
                "wrongcode3139", //temporarily to pass nested-switch test
        ]);
    }

}

Expression evaluateFunction(FuncDeclaration fd, Expressions* args)
{
//    pragma(msg, __traits(allMembers, typeof(*args)));
    return evaluateFunction(fd, args ? (*args)[0 .. args.dim] : []);
}

import dmd.ctfe.bc_common;
import dmd.ctfe.bc_abi;

struct ClosureVariableDescriptor
{
    int offset;
    int depth;
}

ClosureVariableDescriptor* searchInParent(FuncDeclaration fd, VarDeclaration vd)
{
    ClosureVariableDescriptor* cvd = null;
    int offset;
    // if we don't have closureVars ourselfs then we don't need to load our ptr
    // therefore we then start at level -2 rather then -1
    int depth = (fd.closureVars.dim ? -1 : -2);

outer: while(fd)
    {
        depth++;
        offset = 4; // initialze to 4 because of the parent closure pointer
        foreach(cv;fd.closureVars)
        {
            if (cv == vd)
            {
                cvd = cast (ClosureVariableDescriptor*)
                    allocmemory(ClosureVariableDescriptor.sizeof);
                cvd.offset = offset;
                cvd.depth = depth;
                break outer;
            }
            else
            {
                offset += _sharedCtfeState.size(_sharedCtfeState.btv.toBCType(cv.type), true);
            }
        }

        fd = fd.parent.isFuncDeclaration();
    }

    return cvd;

}
enum exceptionPointerAddr = 100;
enum heapStartAddr = exceptionPointerAddr + 4;

__gshared LocType!() lastLoc;

template LocType()
{
    import dmd.globals : Loc;
    alias LocType = Loc;
}

static immutable smallIntegers = [BCTypeEnum.i8, BCTypeEnum.i16, BCTypeEnum.u8, BCTypeEnum.u16, BCTypeEnum.c8, BCTypeEnum.c16];
bool is32BitReg(BCTypeEnum type)
{
    return type.anyOf(smallIntegerTypes) || type.anyOf([BCTypeEnum.f23, BCTypeEnum.c32, BCTypeEnum.i32, BCTypeEnum.u32]);
}

bool is64BitReg(BCTypeEnum type)
{
    return type == BCTypeEnum.u64 || type == BCTypeEnum.i64 || type == BCTypeEnum.f52;
}
bool isPassedByPointer(BCTypeEnum type)
{
    return type == BCTypeEnum.Struct 
        || type == BCTypeEnum.Class
        || type == BCTypeEnum.Slice
        || type == BCTypeEnum.Array
        || type == BCTypeEnum.string8
        || type == BCTypeEnum.AArray
    ;
}

static if (UseLLVMBackend)
{
    import dmd.ctfe.bc_llvm_backend;

    alias BCGenT = LLVM_BCGen;
}
else static if (UseCBackend)
{
    import dmd.ctfe.bc_c_backend;

    alias BCGenT = C_BCGen;
}
else static if (UsePrinterBackend)
{
    import dmd.ctfe.bc_printer_backend;

    alias BCGenT = Print_BCGen;
}
else static if (UseGCCJITBackend)
{
    import dmd.ctfe.bc_gccjit_backend;

    alias BCGenT = GCCJIT_BCGen;
}
else
{
    import dmd.ctfe.bc;

    alias BCGenT = BCGen;
}
__gshared SharedCtfeState!BCGenT _sharedCtfeState;
__gshared SharedCtfeState!BCGenT* sharedCtfeState = &_sharedCtfeState;
__gshared SharedExecutionState _sharedExecutionState;
__gshared SharedExecutionState* sharedExecutionState = &_sharedExecutionState;
__gshared BlackList _blacklist;

ulong evaluateUlong(Expression e)
{
    return e.toUInteger;
}

pragma(msg, "sizeof(SharedExecutionState) = ", int(SharedExecutionState.sizeof/1024), "k");
pragma(msg, "sizeof(SharedCtfeState) = ", int(_sharedCtfeState.sizeof/1024/1024), "M");

uint max (uint a, uint b)
{
    return a < b ? b : a;
}

Expression evaluateFunction(FuncDeclaration fd, Expression[] args)
{
    _blacklist.defaultBlackList();
    import std.stdio;

    // writeln("Evaluating function: ", fd.toString);
    import dmd.identifier;
    import std.datetime.stopwatch : StopWatch;
    import core.time;

    static if (perf)
    {
        StopWatch csw;
        StopWatch isw;
        StopWatch hiw;
        StopWatch psw;
        hiw.start();
    }
    _sharedExecutionState.initHeap();
    _sharedExecutionState.initStack();
    _sharedCtfeState.clearState();
    static if (perf)
    {
        hiw.stop();
        printf("Initializing heap took %d usecs", (cast(int)hiw.peek.total!"usecs"));
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

    // HACK since we don't support dealing with _uncompiled_ functions passed as arguments,
    // search through the arguments and if we detect a function compile it.
    // This did not work because the first function we compile is the one we execute.
    // Hence if visited another function before we began this one we are executing the
    // argument instead of the 'main' function

    foreach(ref arg;args)
    {
        import dmd.tokens;
        if (arg.op == TOK.call)
        {
            auto oldArg = arg;
            arg = .ctfeInterpret(arg);
            //printf("interpreting arg call %s -> %s\n", oldArg.toChars(), arg.toChars());
        }

        else if (arg.type.ty == Tpointer && (cast(TypePointer) arg.type).nextOf.ty == Tfunction)
        {
            import dmd.tokens;
            if (arg.op == TOK.symbolOffset)
            {
                auto se = cast(SymOffExp) arg;
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
    bcv.IGaveUp = false;
    bcv.visit(fd);

    static if (perf)
    {
        csw.stop;
        printf("Creating and Initializing bcGen took %d usecs\n", (cast(int)isw.peek.total!"usecs"));
        printf("Generating bc for %s took %d usecs\n", fd.ident.toChars(), (cast(int)csw.peek.total!"usecs"));
    }

    debug (ctfe)
    {
        import std.stdio;
        import std.algorithm;

//        bcv.vars.keys.each!(k => (cast(VarDeclaration) k).print);
        bcv.vars.writeln;

        writeln("stackUsage = " ~ itos(cast(int)(bcv.sp - 4)) ~ " byte");
        writeln("TemporaryCount = " ~ itos(cast(int)bcv.temporaryCount));
    }

    if (!bcv.IGaveUp)
    {
        import std.algorithm;
        import std.range;
        import std.datetime.stopwatch : StopWatch;
        import std.stdio;

        static if (is(BCGen))
        {
            auto myCode = bcv.byteCodeArray[0 .. bcv.ip].idup;
            auto myIp = bcv.ip;
        }


        BCValue[4] errorValues;
        StopWatch sw;
        StopWatch asw;
        StopWatch asw2;
        sw.start();
        asw.start();

        BCValue[] bc_args;
        bc_args.length = args.length;
        foreach(i, arg;args)
        {
            bc_args[i] = genArg(arg);
            //printf("genArg(%s) -> %s\n", arg.toChars(), toExpression(bc_args[i], arg.type).toChars());
        }

        asw.stop();
        bcv.compileUncompiledFunctions();
        bcv.buildVtbls();
        // FIXME TODO BAD PERFORMANCE we walk the arguments AGAIN after builing the vtbl
        // so we can stick the correct vtbl pointer in.
        // the correct way to do this, is to have a seperate visitor _before_ generating the arguments,
        // which keeps track of all the encoutnered classes and registers them
        asw2.start();
        foreach(i, arg;args)
        {
            bc_args[i] = genArg(arg);
            // printf("genArg(%s) -> %s\n", arg.toChars(), toExpression(bc_args[i], arg.type).toChars());
        }
        asw2.stop();

        //static if (bailoutMessages) bcv.dumpVtbls();
        // we build the vtbls now let's build the constructors
        bcv.compileUncompiledConstructors();
        bcv.compileUncompiledDynamicCasts();
        bcv.compileUncompiledFunctions();

        static if (is(BCGen))
        {
            bcv.ip = myIp;
            bcv.byteCodeArray[0 .. bcv.ip] = myCode[0 .. bcv.ip];
        }

        bcv.Finalize();

        static if (UseLLVMBackend)
        {
            bcv.gen.print();

            auto retval = bcv.gen.interpret(bc_args, &_sharedExecutionState.heap);
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
            // return null;
        }
        else static if (UseGCCJITBackend)
        {
            auto retval = bcv.gen.run(0, bc_args, &_sharedExecutionState.heap);
        }
        else
        {
            debug (output_bc)
            {
                import std.stdio;

                writeln("I have ", _sharedCtfeState.functionCount, " functions!");
                printInstructions(bcv.gen.byteCodeArray[0 .. bcv.ip], bcv.stackMap).writeln();
            }

            auto retval = interpret_(0, bc_args,
                &_sharedExecutionState.heap, &_sharedCtfeState.functions[0], &bcv.calls[0],
                &errorValues[0], &errorValues[1], &errorValues[2], &errorValues[3],
                &_sharedCtfeState.errors[0], _sharedExecutionState.stack[], bcv.stackMap());

        }
        sw.stop();

        auto ft = cast(TypeFunction) fd.type;
        assert(ft.nextOf);

        static if (perf)
        {
            import core.stdc.stdio;
            printf("Executing bc for %s took %d usecs\n", fd.ident.toChars(), (cast(int)sw.peek().total!"usecs"));
            printf("%d us were spent doing argument processing\n", (cast(int)asw.peek().total!"usecs"));
            printf("%d us were spent doing argument re-processing\n", cast(int)asw2.peek().total!"usecs");
        }
        {
            static if (perf)
            {
                StopWatch esw;
                esw.start();
            }
            if (auto exp = toExpression(retval, ft.nextOf, null,
                    &_sharedExecutionState.heap, &errorValues, &_sharedCtfeState.errors[0]))
            {
                static if (perf)
                {
                    esw.stop();
                    import dmd.asttypename;
                    writeln(astTypeName(exp));
                    writeln("Converting to AST Expression took " ~ itos(cast(int)esw.peek().total!"usecs") ~ "us");
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
            // return null;
        }
        static if (bailoutMessages)
            writeln("Gave up!");
        return null;

    }

}

/*
 * params (_e) The Expression to test.
 * Returns 1 if the expression is __ctfe, returns -1 if the expression is !__ctfe, 0 for anything else.
 */
private int is__ctfe(const Expression _e)
{
    import dmd.tokens : TOK;
    import dmd.id : Id;

    int retval = 1;
    Expression e = cast(Expression) _e;

switch_head:
    switch (e.op)
    {
    case TOK.variable:
        {
            if ((cast(VarExp) e).var.ident == Id.ctfe)
                return retval;
            else
                goto default;
        }

    case TOK.not:
        {
            e = (cast(NotExp) e).e1;
            retval = (retval == -1 ? 1 : -1);
            goto switch_head;
        }

    case TOK.identifier:
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
            result = cPtr.fromStringz.idup ~ "    " ~ lPtr.fromStringz.idup;
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

struct BCAArray
{
    BCType elementType;
    BCType keyType;
}


struct BeginStructResult
{
    uint structCount;
    BCStruct* _struct;
    alias _struct this;
}

struct BeginClassResult
{
    uint classCount;
    BCClass* _class;
    alias _class this;

    void addField(const BCType bct, bool isVoid)
    {
        static if (state_logging)
        {
            import std.file : append;
            append("ctfe_state.log", "class[" ~ classCount.itos ~"].members[" ~ memberCount.itos ~ "] = addField(\"" ~ sharedCtfeState.typeToString(bct) ~ "\")\n");
        }
        memberTypes[memberCount++] = bct;
    }
}


struct BCStruct
{
    uint memberCount;
    uint size = StructMetaData.Size;

    BCType[bc_max_members] memberTypes;
    bool[bc_max_members] voidInit;
    Expression[bc_max_members] initializerExps;

    string toString() const
    {
        string result;
        result ~= " Size: " ~ itos(size);
        result ~= " MemberCount: " ~ itos(memberCount);
        result ~= " [";

        foreach(i; 0 .. memberCount)
        {
            result ~= memberTypes[i].toString;
            result ~= " offset: {" ~ itos(offset(i)) ~ "}, ";
        }

        result ~= "]\n";

        return result;
    }

    void addField(const BCType bct, bool isVoid, Expression initExp)
    {
        memberTypes[memberCount] = bct;
        this.initializerExps[memberCount] = initExp;
        voidInit[memberCount++] = isVoid;

        size += align4(_sharedCtfeState.size(bct, true));
    }

    const int offset(const int idx)
    {
        int _offset;
        if (idx == -1)
            return -1;

        debug (ctfe)
            assert(idx <= memberCount);
            else if (idx > memberCount)
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
    uint memberCount;
    uint size = UnionMetaData.Size;

    BCType[bc_max_members] memberTypes;
    bool[bc_max_members] voidInit;
    uint[] initializer;

    string toString() const
    {
        string result;
        result ~= " Size: " ~ itos(size);
        result ~= " MemberCount: " ~ itos(memberCount);
        result ~= " [";

        foreach(i; 0 .. memberCount)
        {
            result ~= memberTypes[i].toString;
        }

        result ~= "]\n";

        return result;
    }

    void addField(const BCType bct, bool isVoid, uint[] initValue)
    {
        if (!memberCount) // if we are on the first field set the initializer
        {
            initializer.length = initValue.length;
            initializer[0 .. initValue.length] = initValue[0 .. initValue.length];
        }

        memberTypes[memberCount] = bct;
        voidInit[memberCount++] = isVoid;

        size = max(align4(_sharedCtfeState.size(bct, true)) + UnionMetaData.Size, size);
    }

}

struct BCClass
{
    uint parentIdx; /// 0 is object
    uint size;
    uint memberCount;
    uint vtblPtr;
    //TODO make the default ctor stuff work.
    FuncDeclaration defaultCtor;
    int defaultCtorIdx;

    int[] usedVtblIdxs;

    BCType[bc_max_members] memberTypes;

    void computeSize()
    {
        uint size = align4(ClassMetaData.Size);
/+
        if (parentIdx)
        {
            auto pct = _sharedCtfeState.classTypes[parentIdx - 1];
            pct.computeSize();
            assert(pct.size >= align4(ClassMetaData.Size));
            size = pct.size;
        }
        else
        {
            size = align4(ClassMetaData.Size);
        }
+/

        foreach (t; memberTypes[0 .. memberCount])
        {
            size += align4(sharedCtfeState.size(t, true));
        }

        this.size = size;
    }

    const int offset(const int idx)
    {
        int _offset = align4(ClassMetaData.Size);
        if (idx == -1)
            return -1;

        debug (ctfe)
            assert(idx <= memberCount);
        else if (idx > memberCount)
                return -1;

        foreach (t; memberTypes[0 .. idx])
        {
            _offset += align4(sharedCtfeState.size(t, true));
        }

        return _offset;
    }

}

struct SharedExecutionState
{
    BCHeap heap;
    long[ushort.max / 4] stack; // a Stack of 64K/4 is the Hard Limit;

    void initStack()
    {
        import core.stdc.string : memset;

        memset(&stack, 0, stack[0].sizeof * stack.length / 4);
    }

    void initHeap(uint maxHeapSize = (__ctfe ? 2 ^^ 23 : 2 ^^ 28))
    {
        import dmd.root.rmem;

        if (heap.heapMax < maxHeapSize)
        {
            void* mem = allocmemory(maxHeapSize * typeof(heap.heapData[0]).sizeof);
            heap.heapData = (cast(typeof(heap.heapData[0])*) mem)[0 .. maxHeapSize];
            heap.heapMax = maxHeapSize;
        }
        else
        {
            import core.stdc.string : memset;

            memset(&heap.heapData[0], 0, heap.heapData[0].sizeof * heap.heapSize);
        }

        heap.heapSize = heapStartAddr;
    }
}

struct SharedCtfeState(BCGenT)
{
    uint _threadLock;

    ClassDeclaration[bc_max_classes] classDeclTypePointers;
    BCClass[bc_max_classes] classTypes;

    StructDeclaration[bc_max_structs] structDeclTypePointers;
    BCStruct[bc_max_structs] structTypes;

    TypeSArray[bc_max_arrays] sArrayTypePointers;
    BCArray[bc_max_arrays] arrayTypes;

    TypeAArray[bc_max_arrays] aArrayTypePointers;
    BCAArray[bc_max_arrays] aArrayTypes;


    TypeDArray[bc_max_slices] dArrayTypePointers;
    BCSlice[bc_max_slices] sliceTypes;

    TypePointer[bc_max_types] pointerTypePointers;
    BCPointer[bc_max_pointers] pointerTypes;

    BCTypeVisitor btv = new BCTypeVisitor();
    pragma(msg, "sizeof typeVisitor instance = ", int(__traits(classInstanceSize, BCTypeVisitor)), "bytes");

    uint structCount;
    uint classCount;
    uint arrayCount;
    uint aArrayCount;
    uint sliceCount;
    uint pointerCount;
    // find a way to live without 102_000
    RetainedError[bc_max_errors] errors;
    uint errorCount;
    pragma(msg, "sizeof errors = ", int(errors.sizeof/1024), "k");

    string typeToString(const BCType type) const
    {
        const(char)[] result;

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
                result = "BCStruct: " ~ (cast()structDeclTypePointers[type.typeIndex - 1]).toString;
            else
                result = type.toString;
        }

        else if (type.type == BCTypeEnum.Class)
        {
            if (type.typeIndex)
                result = "BCClass: " ~ (cast()classDeclTypePointers[type.typeIndex - 1]).toString;
            else
                result = type.toString;
        }

        else
            result = enumToString(type.type) ~ ".toString: " ~ type.toString();

        return cast(string)result;
    }

    const(BCType) elementType(const BCType type) pure const
    {
        if (type.type == BCTypeEnum.Slice)
            return (type.typeIndex && type.typeIndex <= sliceCount) ? sliceTypes[type.typeIndex - 1] .elementType : BCType.init;
        else if (type.type == BCTypeEnum.Ptr)
            return (type.typeIndex && type.typeIndex <= pointerCount) ? pointerTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.Array)
            return (type.typeIndex && type.typeIndex <= arrayCount) ? arrayTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.AArray)
            return (type.typeIndex && type.typeIndex <= aArrayCount) ? aArrayTypes[type.typeIndex - 1].elementType : BCType.init;
        else if (type.type == BCTypeEnum.string8)
            return BCType(BCTypeEnum.c8);
        else
            return BCType.init;
    }

    const(BCType) pointerOf(const BCType type) pure
    {
        foreach (size_t i, pt; pointerTypes[0 .. pointerCount])
        {
            if (pt.elementType == type)
            {
                return BCType(BCTypeEnum.Ptr, cast(uint)(i + 1));
            }
        }

        pointerTypes[pointerCount++] = BCPointer(type);
        return BCType(BCTypeEnum.Ptr, pointerCount);
    }

    const(BCType) sliceOf(const BCType type) pure
    {
        foreach (size_t i, st; sliceTypes[0 .. sliceCount])
        {
            if (st.elementType == type)
            {
                return BCType(BCTypeEnum.Slice, cast(uint)(i + 1));
            }
        }

        sliceTypes[sliceCount++] = BCSlice(type);
        return BCType(BCTypeEnum.Slice, sliceCount);
    }

    void clearState()
    {
        clearArray(sArrayTypePointers, arrayCount);
        clearArray(arrayTypes, arrayCount);
        clearArray(structDeclTypePointers, structCount);
        clearArray(structTypes, structCount);
        clearArray(classDeclTypePointers, classCount);
        clearArray(classTypes, classCount);
        clearArray(dArrayTypePointers, sliceCount);
        clearArray(sliceTypes, sliceCount);
        clearArray(pointerTypePointers, pointerCount);
        clearArray(pointerTypes, pointerCount);
        clearArray(errors, errorCount);

        static if (is(BCFunction))
            clearArray(functions, functionCount);

        errorCount = 0;
        arrayCount = 0;
        structCount = 0;
        classCount = 0;
        sliceCount = 0;
        pointerCount = 0;
        errorCount = 0;

        static if (is(BCFunction))
            _sharedCtfeState.functionCount = 0;
    }


    static if (is(BCFunction))
    {
        static assert(is(typeof(BCFunction.funcDecl) == void*));
        BCFunction[bc_max_functions] functions;
        int functionCount = 0;
    }
    else
    {
        pragma(msg, BCGenT, " does not support BCFunctions");
    }

    bool addStructInProgress;

    import dmd.globals : Loc;


    BCValue addErrorWithMessage(Loc loc, BCValue errorMessage)
    {
        auto sa1 = TypedStackAddr(errorMessage.type, errorMessage.stackAddr);

        errors[errorCount++] = RetainedError(loc, null, sa1);
        auto error = imm32(errorCount);
        error.vType = BCValueType.ErrorWithMessage;
        return error;
    }

    extern (D) BCValue addError(const Loc loc, lazy const(char)[] msg, BCValue v1 = BCValue.init,
        BCValue v2 = BCValue.init, BCValue v3 = BCValue.init,
        BCValue v4 = BCValue.init)
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
        // if we get here the type was not found and has to be registered.
        auto elemType = btv.toBCType(tsa.nextOf);
        // if it's impossible to get the elemType return 0
        if (!elemType.type)
            return 0;
        auto arraySize = evaluateUlong(tsa.dim);
        assert(arraySize < uint.max);
        if (arrayCount == arrayTypes.length)
            return 0;
        sArrayTypePointers[arrayCount] = tsa;
        arrayTypes[arrayCount++] = BCArray(elemType, cast(uint) arraySize);

        return arrayCount;
    }

    int getAArrayIndex(TypeAArray taa)
    {
        foreach (i, aArrayTypePtr; aArrayTypePointers[0 .. aArrayCount])
        {
            if (taa == aArrayTypePtr)
            {
                return cast(uint) i + 1;
            }
        }
        // if we get here the type was not found and has to be registered.
        auto elemType = btv.toBCType(taa.nextOf);
        auto keyType = btv.toBCType(taa.index);

        // if it's impossible to get the elemType return 0
        if (!elemType.type || !keyType.type)
            return 0;

        if (aArrayCount == arrayTypes.length)
            return 0;
        aArrayTypePointers[aArrayCount] = taa;
        aArrayTypes[aArrayCount++] = BCAArray(elemType, keyType);

        return aArrayCount;
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
        // if we get here the type was not found and has to be registered.

        return 0;
    }

    int getStructIndex(StructDeclaration sd)
    {
        if (sd is null)
            return 0;

        foreach (i, structDeclPtr; structDeclTypePointers[0 .. structCount])
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

        /// work because of how more complicated types the type we are looking for
        /// it not nessisarly the last registered one.
        /// therefore we need to search again
        /// however it can only be within the last registred ones
        foreach (i, structDeclPtr; structDeclTypePointers[oldStructCount .. structCount])
        {
            if (structDeclPtr == sd)
            {
                return cast(uint) i + oldStructCount + 1;
            }
        }
        assert(0, "struct type lookup failed!");
    }

    int getClassIndex(ClassDeclaration cd)
    {
        if (cd is null)
            return 0;

        foreach (i, classDeclPtr; classDeclTypePointers[0 .. classCount])
        {
            if (classDeclPtr == cd)
            {
                return cast(uint) i + 1;
            }
        }

        //register structType
        auto oldClassCount = classCount;
        btv.visit(cd);
        assert(oldClassCount < classCount, "Registering a class failed");

        /// work because of how more complicated types the type we are looking for
        /// it not nessisarly the last registered one.
        /// therefore we need to search again
        /// however it can only be within the last registred ones
        foreach (i, classDeclPtr; classDeclTypePointers[oldClassCount .. classCount])
        {
            if (classDeclPtr == cd)
            {
                return cast(uint) i + oldClassCount + 1;
            }
        }
        assert(0, "Class type lookup failed!");
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
            assert(0, "SliceTypeArray overflowed");
        }
    }

    //NOTE beginStruct and endStruct are not threadsafe at this point.

    BeginStructResult beginStruct(StructDeclaration sd)
    {
        structDeclTypePointers[structCount] = sd;
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

    BeginClassResult beginClass(ClassDeclaration cd)
    {
        static if (state_logging)
        {
            import std.file : append;
            append("ctfe_state.log", "class[" ~ classCount.itos ~"] = beginClass(\"" ~ cd.ident.toString ~ "\")\n");
        }
        classDeclTypePointers[classCount] = cd;
        return BeginClassResult(classCount, &classTypes[classCount++]);
    }

    const(BCType) endClass(BeginClassResult* s, bool died)
    {
        static if (state_logging)
        {
            import std.file : append;
            append("ctfe_state.log", "endClass(" ~ s.classCount.itos ~")  ");
        }
        if (died)
        {
            static if (state_logging)
            {
                append("ctfe_state.log", "Died!\n");
            }
            return BCType.init;
        }
        else
        {
            auto type = BCType(BCTypeEnum.Class, s.classCount);
            static if (state_logging)
            {
                import std.file : append;
                s.computeSize();
                append("ctfe_state.log", "Size: " ~ s.size.itos ~ " ParentIdx: " ~ s.parentIdx.itos ~ "\n");
            }
            return type;
        }
    }

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
            writeln("Calling Size for (" ~ enumToString(type.type) ~ ", "
                ~ itos(type.typeIndex) ~ ")");
            //writeln(getTypeString(bct));
            return 0;
        }

        if (isBasicBCType(type))
        {
            assert(type.type == BCTypeEnum.Void || basicTypeSize(type.type) != 0, _sharedCtfeState.typeToString(type) ~ " is both seen as a basicType and has the size of 0");
            return basicTypeSize(type.type);
        }

        switch (type.type)
        {

        case BCTypeEnum.Struct:
            {
                if (type.typeIndex && type.typeIndex <= structCount)
                {
                    // the if above should really be an assert
                    // I have no idea why this even happens
                    return structTypes[type.typeIndex - 1].size;
                }
                assert(0);
            }
        case BCTypeEnum.Class :
            {
                if (type.typeIndex == 0 || type.typeIndex > classCount)
                {
                    assert(0);
                }
                enum PtrSize = 4;
                if (isMember)
                    return PtrSize;

                auto c = _sharedCtfeState.classTypes[type.typeIndex - 1];
                c.computeSize();
                return c.size;
            }
        case BCTypeEnum.Array:
            {
                if(!type.typeIndex || type.typeIndex > arrayCount)
                {
                    // the if above should really be an assert
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
        case BCTypeEnum.string8:
        case BCTypeEnum.Ptr:
        case BCTypeEnum.Slice:
            {
                return SliceDescriptor.Size;
            }
        default:
            {
                debug (ctfe)
                    assert(0, "cannot get size for BCType." ~ enumToString(type.type));
                else
                return 0;
            }

        }
    }
}

struct TypedStackAddr
{
    BCType type;
    StackAddr addr;
}

struct RetainedError // Name is still undecided
{
    import dmd.globals : Loc;

    Loc loc;
    const(char)[] msg;

    TypedStackAddr v1;
    TypedStackAddr v2;
    TypedStackAddr v3;
    TypedStackAddr v4;
}

/// aggBeginAddr is a pointer to heap memory
/// aggPtr is an integer representing a pointer relative to the beginning of the heap
/// meaning aggBeginAddr = &heap[aggPtr];
Expression memberToExpression(const ubyte* aggBeginAddr, uint aggPtr, BCType memberType, uint offset, Type type, Expression[uint] seenPointers)
{
    Expression elm;
    if (is64BitReg(memberType.type))
    {
        BCValue imm64;
        imm64.vType = BCValueType.Immediate;
        imm64.type.type = memberType.type;
        imm64.imm64.imm64 = loadu32(aggBeginAddr + offset)
                          | ulong(loadu32(aggBeginAddr + offset + 4)) << 32;
        elm = toExpression(imm64, type);
    }
    else if (memberType.type != BCTypeEnum.Class && isPassedByPointer(memberType.type))
    {
        elm = toExpression(imm32(aggPtr + offset), type, seenPointers);
    }
    else if (memberType.type == BCTypeEnum.Class)
    {
        //printf("classPtr: %u", (aggPtr + offset));
        //printf("classPtrDref: %u", loadu32(aggBeginAddr + offset));
        //elm = toExpression(imm32(aggPtr + offset), type);
        elm = toExpression(imm32(loadu32(aggBeginAddr + offset)), type, seenPointers);
    }
    else
    {
        debug (abi)
        {
            import std.stdio;
            writeln("memberType: ", memberType);
        }
        elm = toExpression(
            imm32(loadu32(aggBeginAddr + offset)), type, seenPointers);
    }
    if (!elm)
    {
        static if (bailoutMessages)
        {
            import core.stdc.stdio;
            printf("We could not convert the sub-expression of a struct of type %s\n", type.toString.ptr);
        }
    }
    return elm;
}

Expression toExpression(const BCValue value, Type expressionType,
    Expression[uint] seenPointers = null,
    const BCHeap* heapPtr = &_sharedExecutionState.heap,
    const BCValue[4]* errorValues = null, const RetainedError* errors = null)
{
    import dmd.ctfeexpr : ThrownExceptionExp, ClassReferenceExp, CTFEExp;
    debug (abi)
    {
            import std.stdio;
            import std.range;
            import std.algorithm;
            writefln("HeapDump: %s",
                zip(heapPtr.heapData[heapStartAddr .. heapPtr.heapSize], iota(heapStartAddr, heapPtr.heapSize, 1)).map!(e => e[1].itos ~ ":" ~ e[0].itos));
    }

    static if (printResult)
    {
        import std.stdio;
        writeln("Calling toExpression with Type:", (cast(TY)(expressionType.ty)).enumToString, " Value:", value);
    }
    Expression result;
    if (value.vType == BCValueType.Unknown)
    {
        debug (ctfe)
        {
            assert(0, "return value was not set");
        }
        else
        return null;
    }

    if (value.vType == BCValueType.Exception)
    {
        BCType cType = value.type;
        assert(cType.type == BCTypeEnum.Class && cType.typeIndex);

        expressionType =
            _sharedCtfeState.classDeclTypePointers[cType.typeIndex - 1].type;

    }

    StringExp makeString(BCValue value)
    {
        auto length = loadu32(&heapPtr.heapData[value.imm32 + SliceDescriptor.LengthOffset]);
        auto base = loadu32(&heapPtr.heapData[value.imm32 + SliceDescriptor.BaseOffset]);
        uint sz = expressionType.isString ? cast (uint) expressionType.nextOf().size : 1;

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
                writefln("We cannot deal with stringElementSize: %d", sz);
            }
            return null;
        }

        auto offset = cast(uint)base;
        import dmd.root.rmem : allocmemory;

        auto resultString = cast(char*)allocmemory(length * sz + sz);

        assert(sz == 1, "missing UTF-16/32 support");
        foreach (i; 0 .. length)
            resultString[i] = cast(char) heapPtr.heapData[offset + i];
        resultString[length] = '\0';
        StringExp se = new StringExp(lastLoc, cast(void[])resultString[0 .. length]);
        se.type = Type.tstring;
        se.ownedByCtfe = OwnedBy.ctfe;
        assert(se.type);
        return se;
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
            assert(0, "Interpreter had to bail out");
        }
        else
        static if (bailoutMessages)
        {
            import std.stdio;
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
        assert(value.type.type == BCTypeEnum.u32, "Error.type is: " ~ _sharedCtfeState.typeToString(value.type));
        assert(value.imm32, "Errors are 1 based indexes");
        import dmd.ctfeexpr : CTFEExp;

        auto err = _sharedCtfeState.errors[value.imm32 - 1];
        import dmd.errors;

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
        {
            error(err.loc, err.msg.ptr, e1, e2, e3, e4);
        }
        else
        {
            //TODO replace escape sequnces inside the string created
            // by makeString below.
            error(err.loc, "\"%s\"", makeString((*errorValues)[0]).peekString().ptr);
        }

        return CTFEExp.cantexp;
    }

    Expression createArray(BCValue arr, Type arrayType)
    {
        ArrayLiteralExp arrayResult;
        auto elemType = arrayType.nextOf;
        auto bcElemType = _sharedCtfeState.btv.toBCType(elemType);
        auto elemSize = _sharedCtfeState.size(bcElemType, true);

        auto arrayLength = loadu32(&heapPtr.heapData[arr.heapAddr.addr + SliceDescriptor.LengthOffset]);
        auto arrayBase = loadu32(&heapPtr.heapData[arr.heapAddr.addr + SliceDescriptor.BaseOffset]);

        debug (abi)
        {
            import std.stdio;
            import std.range;
            import std.algorithm;
            writefln("creating Array (%s[]) from {base: &%d = %d} {length: &%d = %d} Content: %s",
                _sharedCtfeState.typeToString(_sharedCtfeState.btv.toBCType(arrayType)),
                arr.heapAddr.addr + SliceDescriptor.BaseOffset, arrayBase, arr.heapAddr.addr + SliceDescriptor.LengthOffset, arrayLength,
                zip(heapPtr.heapData[arrayBase .. arrayBase + arrayLength*16*4], iota(arrayBase, arrayBase + arrayLength*16, 1)).map!(e => e[1].itos ~ ":" ~ e[0].itos));
        }

        if (!arr.heapAddr || !arrayBase)
        {
           return new NullExp(lastLoc, arrayType);
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
                // writefln("%d %x", idx, heapPtr.heapData[idx]);
            }
        }

        Expressions* elmExprs = new Expressions(arrayLength);
        uint offset = 0;

        debug (ctfe)
        {
            import std.stdio;

            writeln("building Array of Length ", arrayLength);
        }
        /* import std.stdio;
            writeln("HeapAddr: ", value.heapAddr.addr);
            writeln((cast(char*)(heapPtr.heapData.ptr + value.heapAddr.addr + 1))[0 .. 64]);
            */

        auto aggPtr = arrayBase;
        auto aggBeginAddr = &heapPtr.heapData[aggPtr];

        foreach (idx; 0 .. arrayLength)
        {
            (*elmExprs)[idx] = memberToExpression(aggBeginAddr, aggPtr, bcElemType, offset, elemType, seenPointers);
            offset += elemSize;
        }

        arrayResult = new ArrayLiteralExp(lastLoc, arrayType, elmExprs);
        arrayResult.ownedByCtfe = OwnedBy.ctfe;

        return arrayResult;
    }

    if (expressionType.isString)
    {
        if (!value.imm32 || !loadu32(&heapPtr.heapData[value.imm32 + SliceDescriptor.BaseOffset]))
        {
            {
                return new NullExp(lastLoc, expressionType);
            }
        }
        else
            return makeString(value);
    }
    else
        switch (expressionType.ty)
    {

    // XXX: case Tenum was commented out .... why ????
    case Tenum:
        {
            result = toExpression(value, (cast(TypeEnum)expressionType).toBasetype(), seenPointers);
        }
        break;

    case Tstruct:
        {
            auto sd = (cast(TypeStruct) expressionType).sym;
            auto si = _sharedCtfeState.getStructIndex(sd);
            assert(si);
            BCStruct _struct = _sharedCtfeState.structTypes[si - 1];

            auto aggPtr = value.imm32.imm32;
            auto aggBeginAddr = &heapPtr.heapData[aggPtr];
            Expressions* elmExprs = new Expressions(_struct.memberCount);

            uint offset = 0;
            debug (abi)
            {
                import std.stdio;
                writeln("structType: ", _struct);
                writeln("StructHeapRep: ", aggBeginAddr[0 .. _struct.size]);
            }
            foreach (idx, memberType; _struct.memberTypes[0 .. _struct.memberCount])
            {
                debug (abi)
                {
                    writeln("StructIdx:", si, " memberIdx: " ,  idx, " offset: ", offset);
                }
                auto type = sd.fields[idx].type;
                auto name = sd.fields[idx].toChars();

                Expression elm = memberToExpression(aggBeginAddr, aggPtr, memberType, offset, type, seenPointers);

                if (!elm)
                {
                    static if (bailoutMessages)
                    {
                        import core.stdc.stdio;
                        printf("We could not convert the sub-expression of a struct of type %s\n", type.toString.ptr);
                    }
                    return null;
                }

                (*elmExprs)[idx] = elm;
                offset += align4(_sharedCtfeState.size(memberType, true));
            }
            result = new StructLiteralExp(lastLoc, sd, elmExprs);
            (cast(StructLiteralExp) result).ownedByCtfe = OwnedBy.ctfe;
        }
        break;
    case Tclass:
        {
            auto aggPtr = value.imm32.imm32;
            auto aggBeginAddr = &heapPtr.heapData[aggPtr];
            bool isNullClass = (aggPtr == 0);
            if (!isNullClass)
            {
                // we need to keep track of class pointer we have seen before
                // otherwise we cannot refer to the same instance
                if (auto e = aggPtr in seenPointers)
                {
                    result = *e;
                    break;
                }
                else
                {
                    seenPointers[aggPtr] = null;
                }
                //FIXME: we should not use a slice here
                //find a better way to get at the memberTypes
                // we need to reconsruct the class layout ... again
                // what a pain!

                auto ci = loadu32(&aggBeginAddr[ClassMetaData.TypeIdIdxOffset]);
                auto vtblPtr = loadu32(&aggBeginAddr[ClassMetaData.VtblOffset]);
                //printf("vtblPtr: %d: %p\n", ci, vtblPtr);
                assert(ci);
                auto cd = _sharedCtfeState.classDeclTypePointers[ci - 1];
                BCClass _class = _sharedCtfeState.classTypes[ci - 1];

                int n_base_classes;

                ClassDeclaration[64] base_classes;
                for(ClassDeclaration baseClass = cd; baseClass; baseClass = baseClass.baseClass)
                {
                    base_classes[n_base_classes++] = baseClass;
                }

                VarDeclaration[] fields;
                foreach_reverse(i; 0 .. n_base_classes)
                {
                    foreach(f;base_classes[i].fields)
                    {
                        fields ~= f;
                    }
                }

                Expressions* elmExprs = new Expressions(_class.memberCount);

                uint offset = ClassMetaData.Size;

                import core.stdc.string : strlen;
                import std.algorithm : map;
                debug (abi)
                {
                    import std.stdio;
                    writeln("class.size: ", _class.size);
                    writeln("aggPtr: ", aggPtr);
                    writeln("value: ", value.imm32.imm32);
                    writeln("ClassHeapRep: ", aggBeginAddr[0 .. _class.size]);
                }
                foreach (idx, memberType; _class.memberTypes[0 .. _class.memberCount])
                {
                    debug (abi)
                    {
                        writeln("ClassIdx:", ci, " memberIdx: " ,  idx, " offset: ", offset);
                    }
                    auto type = fields[idx].type;
                    auto name = fields[idx].toChars();
                    Expression elm = memberToExpression(aggBeginAddr, aggPtr, memberType, offset, type, seenPointers);

                    (*elmExprs)[idx] = elm;
                    offset += align4(_sharedCtfeState.size(memberType, true));
                }

                auto se = new StructLiteralExp(lastLoc, cast(StructDeclaration)cd, elmExprs);
                se.ownedByCtfe = OwnedBy.ctfe;
                result = new ClassReferenceExp(lastLoc, se, expressionType);
                seenPointers[aggPtr] = result;
            }
            else
            {
                result = new NullExp(lastLoc, expressionType);
            }
        }
        break;

    case Tsarray:
        {
            auto tsa = cast(TypeSArray) expressionType;
            assert(loadu32(&heapPtr.heapData[value.heapAddr.addr + SliceDescriptor.LengthOffset])
                     == evaluateUlong(tsa.dim),
                "static arrayLength mismatch: &" ~ itos(value.heapAddr.addr + SliceDescriptor.LengthOffset) ~ " (" ~ itos(loadu32(&heapPtr.heapData[value.heapAddr.addr + SliceDescriptor.LengthOffset])) ~ ") != " ~ itos(
                    cast(int)evaluateUlong(tsa.dim)));
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
            result = new RealExp(lastLoc, *cast(float*)&value.imm32, expressionType);
        }
        break;
    case Tfloat64, Tfloat80:
        {
            result = new RealExp(lastLoc, *cast(double*)&value.imm64, expressionType);
        }
        break;
    case Tint32, Tuns32, Tint16, Tuns16, Tint8, Tuns8, Tchar:
        {
            result = new IntegerExp(lastLoc, value.imm32, expressionType);
        }
        break;
    case Tint64, Tuns64:
        {
            result = new IntegerExp(lastLoc, value.imm64, expressionType);
        }
        break;
    case Tpointer:
        {
            //FIXME this will _probably_ only work for basic types with one level of indirection (eg, int*, uint*)
            if (expressionType.nextOf.ty == Tvoid)
            {
                static if (bailoutMessages)
                {
                    import core.stdc.stdio;
                    printf("trying to build void ptr ... we cannot really do this\n");
                }
                return null;
            }
            result = new AddrExp(lastLoc,
                toExpression(imm32(loadu32(&heapPtr.heapData[value.heapAddr])), expressionType.nextOf, seenPointers));
        }
        break;
    default:
        {
            debug (ctfe)
                assert(0, "Cannot convert to " ~ expressionType.toString() ~ " yet.");
        }
    }
    if (result)
        result.type = expressionType;

    static if (bailoutMessages)
    {
        if (!result)
        {
            import core.stdc.stdio;
            printf("could not create expression of type: %s\n", enumToString(cast(TY)expressionType.ty).ptr);
        }
    }
    if (value.vType == BCValueType.Exception)
    {
        auto thrown_exp =  new ThrownExceptionExp(lastLoc, cast(ClassReferenceExp)result);
        thrown_exp.generateUncaughtError();
        result = CTFEExp.cantexp;
    }
    return result;
}

extern (C++) final class BCArgumentVisitor : Visitor
{
    BCValue result;
    BCTypeEnum[] inTypeStack;
    BCType asBCType;
    uint[] offsets;
    BCValue[void*] cache;

    alias visit = typeof(super).visit;

    bool inAggregate()
    {
        if (inTypeStack.length)
        {
            auto currentType = inTypeStack[$-1];
            return (currentType == BCTypeEnum.Struct || currentType == BCTypeEnum.Class);
        }
        return false;
    }

    bool inStruct()
    {
        if (inTypeStack.length)
        {
            auto currentType = inTypeStack[$-1];
            return (currentType == BCTypeEnum.Struct);
        }
        return false;
    }

    bool inArrayOrSlice()
    {
        if (inTypeStack.length)
        {
            auto currentType = inTypeStack[$-1];
            return (currentType == BCTypeEnum.Array || currentType == BCTypeEnum.Slice);
        }
        return false;
    }

    bool inArray()
    {
        if (inTypeStack.length)
        {
            auto currentType = inTypeStack[$-1];
            return (currentType == BCTypeEnum.Array);
        }
        return false;
    }

    import dmd.ctfeexpr : ClassReferenceExp;
    override void visit(ClassReferenceExp cre)
    {
        auto offset = (offsets.length ? offsets[$-1] : 0);
        auto cIdx = _sharedCtfeState.getClassIndex(cre.originalClass());
        assert(cIdx);
        BCType cType = BCType(BCTypeEnum.Class, cIdx);

        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                pushImm32(result.imm32, offset);
                assert(offsets.length != 0);
                auto storage_size = _sharedCtfeState.size(cType, true);
                assert(storage_size == 4);
                offset += storage_size;
                offsets[$-1] = offset;
            }
        }


        if (auto r = cast(void*)cre in cache)
        {
            result = *r;
        }
        else
        {
            BCClass _class = _sharedCtfeState.classTypes[cIdx - 1];
            auto ct = _sharedCtfeState.classDeclTypePointers[cIdx - 1];

            uint memory = staticAllocAlign4(_class.size);
            auto classVal = imm32(memory);
            classVal.type = BCType(BCTypeEnum.Class, cIdx);
            cache[cast(void*)cre] = classVal;

            inTypeStack ~= BCTypeEnum.Class;
            pushImm32(_class.vtblPtr, memory + ClassMetaData.VtblOffset);
            pushImm32(cIdx, memory + ClassMetaData.TypeIdIdxOffset);

            offsets ~= memory + ClassMetaData.Size;
            auto checkOffset = offsets[$-1];
            foreach (i, elem; *cre.value.elements)
            {
                asBCType = _class.memberTypes[i];
                if (!elem)
                {
                    assert(0, "NullElement encountered in: " ~ cre.toString);
                }
                elem.accept(this);
                auto elexpr = result;

                checkOffset += _sharedCtfeState.size(asBCType, true);
            }

    //        assert(checkOffset == offsets[$-1]);
            inTypeStack = inTypeStack[0 .. $-1];
            offsets = offsets[0 .. $-1];

            result = classVal;
        }
        // printf("\nConverted \n%s\n -> (%d) \n%s\n\n", cre.toChars(), result.imm32.imm32, toExpression(result, cre.type).toChars());
    }

    override void visit(NullExp e)
    {
        auto bct = _sharedCtfeState.btv.toBCType(e.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);
        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                pushValue(result, offset);
                assert(offsets.length != 0);
                offset += _sharedCtfeState.size(bct, true);
                offsets[$-1] = offset;
            }
        }

        result = imm32(0);
        result.vType = BCValueType.Immediate;
        result.type.type = BCTypeEnum.Null;
    }

    override void visit(VarExp e)
    {
        auto bct = _sharedCtfeState.btv.toBCType(e.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);
        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                assert(offsets.length != 0);
                offset += _sharedCtfeState.size(bct, true);
                offsets[$-1] = offset;
            }
        }

        auto fd = e.var.isFuncDeclaration();
        auto vd = e.var.isVarDeclaration();
        auto sd = e.var.isSymbolDeclaration();
        if (fd) printf("fd: %s\n", fd.toChars());
        if (sd) printf("sd: %s\n", sd.toChars());
        if (vd)
        {
            assert(vd._init);
            auto expi = vd._init.isExpInitializer();
            import dmd.asttypename;
            assert(expi, "vd init is: " ~ vd._init.astTypeName());
            expi.exp.accept(this);
        }
        else assert(0, "TODO Implement varExps that eval to symbols or functions");
/+
        result = imm32(0);
        result.vType = BCValueType.Immediate;
        result.type.type = BCTypeEnum.Null;
+/
    }

    override void visit(NewExp e)
    {
        Expression interpreted = e.ctfeInterpret();
        interpreted.accept(this);
    }

    override void visit(CallExp e)
    {
        Expression interpreted = e.ctfeInterpret();
        interpreted.accept(this);
    }

    override void visit(CastExp e)
    {
        Expression interpreted = e.ctfeInterpret();
        interpreted.accept(this);
    }

    override void visit(SliceExp e)
    {
        Expression interpreted = e.ctfeInterpret();
        interpreted.accept(this);
    }

    override void visit(Expression e)
    {
        import dmd.asttypename;
        assert(0, "Cannot handle Expression: " ~ e.astTypeName ~  " :: " ~ e.toString);
    }

    override void visit(CommaExp ce)
    {
        ce.e2.accept(this);
    }

    override void visit(DeleteExp d)
    {}

    override void visit(StringExp se)
    {
        auto bct = _sharedCtfeState.btv.toBCType(se.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);
        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                assert(offsets.length != 0);
                offset += _sharedCtfeState.size(bct, true);
                offsets[$-1] = offset;
            }
        }

        if (!se || se.sz > 1 /* || se.string[se.len] != 0*/ )
        {
            assert(0, "only char strings are supported for now");
        }
        uint sz = se.sz;
        assert(se.len < 2 ^^ 24, "String too big!!");
        uint length = cast(uint)se.len;

        // include space for 0 terminator
        const string_data_size = align4((length * sz) + sz);

        uint string_data_start;
        uint memory;
        // in the case where we can write ourselves into provided memory
        // there is no need to allocate our own slice descriptor
        if (inArray() || inAggregate())
        {
            memory = offset;
            string_data_start = staticAllocAlign4(string_data_size);
        }
        else
        {
            memory = staticAllocAlign4(align4(SliceDescriptor.Size) + string_data_size);
            string_data_start = memory + align4(SliceDescriptor.Size);
        }


        pushSliceDescriptor(string_data_start, length, memory);
        switch(sz)
        {
            case 1 : pushString8Data(se.peekString()[0 .. length], string_data_start); break;
            default : assert(0, "char_size: " ~ itos(sz) ~" unsupported");
        }

        BCValue stringAddr;
        stringAddr = imm32(memory);
        stringAddr.type = BCType(BCTypeEnum.string8);
        result = stringAddr;
    }


    override void visit(StructLiteralExp sle)
    {
        auto bct = _sharedCtfeState.btv.toBCType(sle.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);
        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                //pushValue(result, offset);
                assert(offsets.length != 0);
                offset += _sharedCtfeState.size(bct, true);
                offsets[$-1] = offset;
            }
        }

        auto sd = sle.sd;
        auto idx = _sharedCtfeState.getStructIndex(sd);
        if (!idx)
        {
            assert(0, "structType could not be found: " ~ sd.toString);
        }
        BCStruct _struct = _sharedCtfeState.structTypes[idx - 1];
        auto st = _sharedCtfeState.structDeclTypePointers[idx - 1];

        auto struct_size = align4(_struct.size);

        if (!struct_size)
        {
            assert(0, "invalid struct size! (someone really messed up here!!)");
        }

        int memory;
        if (inAggregate() || inArray())
        {
            memory = offsets[$-1];
        }
        else
        {
            memory = staticAllocAlign4(_struct.size);
        }
        inTypeStack ~= BCTypeEnum.Struct;
        offsets ~= memory;

        auto checkOffset = offsets[$-1];
        foreach (i, elem; *sle.elements)
        {
            asBCType = _struct.memberTypes[i];

            if (!elem)
            {
                assert(0, "NullElement encountered in: " ~ sle.toString);
            }
            auto elemSize = _sharedCtfeState.size(asBCType, true);

            elem.accept(this);
            auto elexpr = result;

            debug (ctfe)
            {
                import std.stdio;
                writeln("elExpr: ", elexpr.toString, " elem ", elem.toString);
            }

            if (!elexpr)
            {
                assert(0, "could not gen StructLiteralElement: " ~ elem.toString);
            }

            checkOffset += align4(elemSize);
        }
        assert(checkOffset == offsets[$-1], "realOffset (" ~ itos(offsets[$-1]) ~ ") != computedOffset (" ~ itos(checkOffset) ~ ")");

        inTypeStack = inTypeStack[0 .. $-1];
        offsets = offsets[0 .. $-1];

        auto structVal = imm32(memory);
        structVal.type = BCType(BCTypeEnum.Struct, idx);
        result = structVal;
    }

    override void visit(ArrayLiteralExp ale)
    {
        auto bct = _sharedCtfeState.btv.toBCType(ale.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);


        auto arrayType = ale.type.isTypeSArray();
        BCArray _array;
        BCType elemType;
        uint idx;
        if (arrayType)
        {
            idx = _sharedCtfeState.getArrayIndex(arrayType);
            if (!idx)
            {
                assert(0, "arrayType could not be found: " ~ ale.type.toString);
            }
            _array = _sharedCtfeState.arrayTypes[idx - 1];
            auto at = _sharedCtfeState.sArrayTypePointers[idx - 1];
            elemType = _array.elementType;
        }
        else
        {
            elemType = _sharedCtfeState.btv.toBCType(ale.type.nextOf());
            _array = BCArray(elemType, cast(int)ale.elements.length);
            idx = _sharedCtfeState.arrayCount + 1;
            _sharedCtfeState.arrayTypes[sharedCtfeState.arrayCount++] = _array;
        }

        const elemSize = _sharedCtfeState.size(elemType, true);
        const arraySize = align4(elemSize) * _array.length;

        if (!arraySize && _array.length)
        {
            assert(0, "invalid array size! (someone really messed up here!!)");
        }

        uint memory;
        uint baseAt;

        if (inArray() || inAggregate())
        {
            memory = offsets[$-1];
            baseAt = staticAllocAlign4(arraySize, true);
        }
        else
        {
            memory = staticAllocAlign4(align4(SliceDescriptor.Size) + arraySize);
            baseAt = memory + align4(SliceDescriptor.Size);
        }
        pushSliceDescriptor(baseAt, _array.length, memory);

        inTypeStack ~= BCTypeEnum.Array;
        offsets ~= baseAt;
        auto checkOffset = offsets[$-1];
        foreach (i, elem; *ale.elements)
        {
            if (!elem)
            {
                elem = ale.basis;
            }
            assert(elem);

            asBCType = _array.elementType;

            elem.accept(this);
            auto elexpr = result;

            debug (ctfe)
            {
                import std.stdio;
                writeln("elExpr: ", elexpr.toString, " elem ", elem.toString);
            }

            if (!elexpr)
            {
                assert(0, "could not gen StructLiteralElement: " ~ elem.toString);
            }
            checkOffset += align4(elemSize);
        }
        assert(checkOffset == offsets[$-1], "realOffset (" ~ itos(offsets[$-1]) ~ ") != computedOffset (" ~ itos(checkOffset) ~ ") -- baseAt: " ~ itos(baseAt));

        inTypeStack = inTypeStack[0 .. $-1];
        offsets = offsets[0 .. $-1];

        auto arrayVal = imm32(memory);
        arrayVal.type = BCType(BCTypeEnum.Array, idx);
        result = arrayVal;

        printf("Converted %s -> %s\n", ale.toChars(), toExpression(result, ale.type).toChars());

        if (inArray() || inAggregate())
        {
            assert(offsets.length != 0);
            offset += _sharedCtfeState.size(bct, true);
            offsets[$-1] = offset;
        }
    }


    void pushValue (BCValue value, uint valueAt)
    {
        assert(value.vType == BCValueType.Immediate);

        if (is64BitReg(value.type.type))
        {
            pushImm64(value.imm64, valueAt);
        }
        else if (is32BitReg(value.type.type))
        {
            pushImm32(value.imm32, valueAt);
        }
        else if (value.type.type == BCTypeEnum.Null)
        {
            pushImm32(0, valueAt);
        }
        else assert(0, "don't know how to push value: " ~ _sharedCtfeState.typeToString(value.type));
    }

    override void visit(SymOffExp se)
    {
        auto bct = _sharedCtfeState.btv.toBCType(se.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);
/+
        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                pushValue(result, offset);
                assert(offsets.length != 0);
                offset += _sharedCtfeState.size(bct, true);
                offsets[$-1] = offset;
            }
        }
+/
        assert(se.var, "!se.var");
        auto fd = se.var.isFuncDeclaration();
        auto fnIdx = _sharedCtfeState.getFunctionIndex(fd);
        if (fd && fnIdx)
        {
            result = pushImm32(fnIdx, 0);
            result.type = BCType(BCTypeEnum.Function, fnIdx);
        }
        else
        {
            assert(0, "encounted unresolved function pointer in arguments");
        }
    }

    override void visit(IntegerExp ie)
    {
        auto bct = _sharedCtfeState.btv.toBCType(ie.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);
        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                pushValue(result, offset);
                assert(offsets.length != 0);
                offset += align4(_sharedCtfeState.size(bct, true));
                offsets[$-1] = offset;
            }
        }

        //scope typeVis = new BCTypeVisitor();
        if (bct.type != BCTypeEnum.i32 && bct.type != BCTypeEnum.i64 && bct.type != BCTypeEnum.c8 &&
            bct.type != BCTypeEnum.c32 && bct.type != BCTypeEnum.i8 && bct.type != BCTypeEnum.u32 &&
            bct.type != BCTypeEnum.u64 && bct.type != BCTypeEnum.u8)
        {
            //NOTE this can happen with cast(char*)size_t.max for example
            assert(0, "We don't support IntegerExpressions with non-integer types: " ~ enumToString(bct.type));
        }

        if (bct.type == BCTypeEnum.i64)
        {
            result = BCValue(Imm64(ie.getInteger()));
        }
        else if (bct.type == BCTypeEnum.u64)
        {
            result = BCValue(Imm64(cast(ulong)ie.getInteger(), false));
        }
        else
        {
            if (ie.type.ty == Tuns32)
            {
                result = BCValue(Imm32(cast(uint)ie.getInteger(), false));
                result.type = bct;
            }
            else
            {
                result = imm32(cast(int) ie.getInteger());
                result.type = bct;
            }
        }
        //auto value = evaluateUlong(ie);
        //result = value <= int.max ? imm32(cast(uint) value) : BCValue(Imm64(value));
        assert(result.vType == BCValueType.Immediate);
    }

    override void visit(RealExp re)
    {
        auto bct = _sharedCtfeState.btv.toBCType(re.type);
        auto offset = (offsets.length ? offsets[$-1] : 0);

        scope(exit)
        {
            if (inArray() || inAggregate())
            {
                pushValue(result, offset);
                assert(offsets.length != 0);
                offset += _sharedCtfeState.size(bct, true);
                offsets[$-1] = offset;
            }
        }

        if (re.type.ty == Tfloat32)
        {
            float tmp = cast(float)re.value;
            result = imm32(*cast(uint*)&tmp);
            result.type.type = BCTypeEnum.f23;
        }
        else if (re.type.ty == Tfloat64)
        {
            double tmp = cast(double)re.value;
            result = BCValue(Imm64(*cast(ulong*)&tmp));
 
            result.type.type = BCTypeEnum.f52;
        }
        else
            assert(0, "RealExp of type " ~ enumToString(cast(TY)re.type.ty)
                ~ " unsupported");
    }

    extern (D) BCValue pushString8Data(const(char)[] data, uint valueAt)
    {
        const arraySize = align4((cast(uint)data.length));
        if (!valueAt)
        {
            valueAt = _sharedExecutionState.heap.heapSize;
            _sharedExecutionState.heap.heapSize += arraySize;
        }

        foreach(i, c;data)
        {
            _sharedExecutionState.heap.heapData[valueAt + i] = c;
        }

        return imm32(valueAt);
    }

    BCValue pushImm64(Imm64 v, uint valueAt)
    {
        return pushImm64(v.imm64, valueAt);
    }

    BCValue pushImm32(Imm32 v, uint valueAt)
    {
        return pushImm32(v.imm32, valueAt);
    }

    BCValue pushImm64(ulong v, uint valueAt)
    {
        if (!valueAt)
        {
            valueAt = _sharedExecutionState.heap.heapSize;
            _sharedExecutionState.heap.heapSize += 8;
        }
        storeu32(&_sharedExecutionState.heap.heapData[valueAt],     (v & uint.max));
        storeu32(&_sharedExecutionState.heap.heapData[valueAt + 4], (v >> 32));

        return imm32(valueAt);
    }

    BCValue pushImm8(ubyte v, uint valueAt)
    {
        if (!valueAt)
        {
            valueAt = _sharedExecutionState.heap.heapSize;
            _sharedExecutionState.heap.heapSize += 1;
        }
        _sharedExecutionState.heap.heapData[valueAt] = v;

        return imm32(valueAt);
    }

    BCValue pushImm32(uint v, uint valueAt)
    {
        if (!valueAt)
        {
            valueAt = _sharedExecutionState.heap.heapSize;
            _sharedExecutionState.heap.heapSize += 4;
        }
        storeu32(&_sharedExecutionState.heap.heapData[valueAt], v);

        return imm32(valueAt);
    }

    extern (D) BCValue pushData(ubyte[] array, uint valueAt)
    {
        const arraySize = array.length;

        if (!valueAt)
        {
            valueAt = _sharedExecutionState.heap.heapSize;
            _sharedExecutionState.heap.heapSize += arraySize;
        }

        _sharedExecutionState.heap.heapData[valueAt .. valueAt + arraySize]
            = array[0 .. arraySize];

        return imm32(valueAt);
    }

    BCValue pushSliceDescriptor(uint base, uint length, uint valueAt)
    {
        if (!valueAt)
        {
            valueAt = _sharedExecutionState.heap.heapSize;
            _sharedExecutionState.heap.heapSize += SliceDescriptor.Size;
        }
        pushImm32(base, valueAt + SliceDescriptor.BaseOffset);
        pushImm32(length, valueAt + SliceDescriptor.LengthOffset);

        return imm32(valueAt);
    }

    uint staticAllocAlign4(uint size, bool allowZeroSize = false)
    {
        assert(allowZeroSize || size, "one may not allocate zero bytes");
        size = align4(size);

        assert(_sharedExecutionState.heap.heapSize + size <
            _sharedExecutionState.heap.heapMax, "heap overflow in static allocation");

        auto memoryAt = _sharedExecutionState.heap.heapSize;
        _sharedExecutionState.heap.heapSize += size;
        return memoryAt;
    }
}

BCValue genArg(Expression e)
{
    scope argumentVisitor = new BCArgumentVisitor();
    e.accept(argumentVisitor);
    return argumentVisitor.result;
}

extern (C++) final class BCTypeVisitor : Visitor
{
    alias visit = typeof(super).visit;
    Type topLevelType;
    uint prevAggregateTypeCount;
    Type[32] prevAggregateTypes;

    const(BCType) toBCType(Type t, Type tla = null, int line = __LINE__) /*pure*/
    {
        assert(t !is null, "t is null when called from: " ~ itos(line));
        switch (t.ty)
        {
        case TY.Tbool:
            //return BCType(BCTypeEnum.i1);
            return BCType(BCTypeEnum.i32);
        case TY.Tchar:
            return BCType(BCTypeEnum.c8);
        case TY.Twchar:
            //return BCType(BCTypeEnum.c16);
        case TY.Tdchar:
            return BCType(BCTypeEnum.c32);
        case TY.Tuns8:
            return BCType(BCTypeEnum.u8);
        case TY.Tint8:
            return BCType(BCTypeEnum.i8);
        case TY.Tuns16:
            return BCType(BCTypeEnum.u16);
        case TY.Tint16:
            return BCType(BCTypeEnum.i16);
        case TY.Tuns32:
            return BCType(BCTypeEnum.u32);
        case TY.Tint32:
            return BCType(BCTypeEnum.i32);
        case TY.Tuns64:
            return BCType(BCTypeEnum.u64);
        case TY.Tint64:
            return BCType(BCTypeEnum.i64);
        case TY.Tfloat32:
            return BCType(BCTypeEnum.f23);
        case TY.Tfloat64:
            return BCType(BCTypeEnum.f52);
        case TY.Tfloat80:
            return BCType(BCTypeEnum.f52);
        case TY.Timaginary32:
        case TY.Timaginary64:
        case TY.Timaginary80:
        case TY.Tcomplex32:
        case TY.Tcomplex64:
        case TY.Tcomplex80:
            return BCType.init;
        case TY.Tvoid:
            return BCType(BCTypeEnum.Void);
        default:
            break;
        }
        // If we get here it's not a basic type;
        assert(!t.isTypeBasic(), "Is a basicType: " ~ (cast(TY) t.ty).enumToString);
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

            if (rt.type)
            {
                et = _sharedCtfeState.elementType(rt);
            }
            if (!et.type)
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

            if (rt.type)
            {
                et = _sharedCtfeState.elementType(rt);
            }
            if (!et.type)
            {
                rt = BCType.init;
            }

            return rt;
        }
        else if (t.ty == Taarray)
        {
            auto taa = cast(TypeAArray) t;
            auto rt = BCType(BCTypeEnum.AArray, _sharedCtfeState.getAArrayIndex(taa));
            BCType et, kt;
            if (rt.type && rt.typeIndex)
            {
                BCAArray aarray =_sharedCtfeState.aArrayTypes[rt.typeIndex - 1];
                et = aarray.elementType;
                kt = aarray.keyType;
            }
            if (!et.type || !kt.type)
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
        else if (t.ty == Tclass)
        {
            auto cd = (cast(TypeClass) t).sym;
            uint classIndex = _sharedCtfeState.getClassIndex(cd);
            return classIndex ? BCType(BCTypeEnum.Class, classIndex) : BCType.init;
        }
        else if (t.ty == Tfunction)
        {
            return BCType(BCTypeEnum.Function);
        }
        else if (t.ty == Tdelegate)
        {
            return BCType(BCTypeEnum.Delegate);
        }

        debug (ctfe)
            assert(0, "NBT Type unsupported " ~ (cast(Type)(t)).toString);
        else
        return BCType.init;
    }

    override void visit(ClassDeclaration cd)
    {
        lastLoc = cd.loc;
        bool died = false;

        int parentIdx = 0;

        if (cd.baseClass)
        {

            parentIdx = _sharedCtfeState.getClassIndex(cd.baseClass);
            assert(parentIdx);
        }

        auto ct = sharedCtfeState.beginClass(cd);

        ct.parentIdx = parentIdx;

        // add parent fields before the current ones.
        // FIXME this this really needed
        // and if it is do we have to rewrite computeSize?

        if (ct.parentIdx)
        {
            auto pc = _sharedCtfeState.classTypes[ct.parentIdx - 1];
            foreach(f;pc.memberTypes[0 .. pc.memberCount])
            {
                ct.addField(f, false);
            }
        }

        foreach(VarDeclaration f;cd.fields)
        {
            ct.addField(toBCType(f.type), f._init ? !!f._init.isVoidInitializer : false);
        }

        sharedCtfeState.endClass(&ct, died);
    }

    override void visit(StructDeclaration sd)
    {
        lastLoc = sd.loc;

        auto st = sharedCtfeState.beginStruct(sd);
        bool died;

        // keep track field which could be processed without problems
        // in order to print out the field where stuff went wrong
        VarDeclaration currentField;
        const(char)[] reason;

//        __gshared static bcv = new BCV!BCGenT; // TODO don't do this.
        import dmd.asttypename;
        addFieldLoop : foreach (mi, sMember; sd.fields)
        {
            bool calledSemantic = false;

            assert(sMember.type);

            if (!died) currentField = sMember;

            if (sMember.type.ty == Tstruct && (cast(TypeStruct) sMember.type).sym == sd)
                assert(0, "recursive struct definition this should never happen");

            // look for previous field with the same offset
            // since we do not handle those currently
            if (mi < 0 && sd.fields[mi - 1].offset == sMember.offset)
            {
                died = true;
                reason = "Overlapping fields";
                break addFieldLoop;
            }

            auto bcType = toBCType(sMember.type);
            if (!bcType.type)
            {
                // if the memberType is invalid we abort!
                died = true;
                reason = "BCType could not be generated for -- " ~ sMember.toString;
                break addFieldLoop;
            }
            else if (sMember._init)
            {
                Expression initExp;
                if (sMember._init.isVoidInitializer)
                    st.addField(bcType, true, null);
                else
                {
                    import dmd.initsem;
                    initExp = initializerToExpression(sMember._init);
                    if(initExp)
                    {
                        if(!initExp.type && !calledSemantic)
                        {
                            import dmd.expressionsem;
                            initExp = initExp.expressionSemantic(sMember._scope);
                            calledSemantic = true;
                        }

                        if (!initExp.type && calledSemantic)
                        {
                            died = true;
                            import dmd.asttypename;
                    reason = "type " ~ initExp.type.toString ~ "could not be generated initExp: -- " ~ initExp.toString
                ~ " -- " ~ astTypeName(initExp) ~ " initExp.tok: " ~ enumToString(initExp.op);
                            break addFieldLoop;

                        }
                    }
                    else
                        assert(0, "We cannot deal with this initalizer -- " ~ sMember._init.toString() ~ " asttypename: " ~ sMember._init.astTypeName());
                        //FIXME change the above assert to something we can bail out on

                    st.addField(bcType, false, initExp);
                }

            }
            else
                st.addField(bcType, false, null);
        }
        // assert(!died, "We died while generting Field  -- " ~ currentField.toString ~ " for struct -- " ~ sd.toString ~ "\n\t" ~ reason);
        _sharedCtfeState.endStruct(&st, died);
    }

}

struct BCScope
{

    //    Identifier[64] identifiers;
    BCBlock[64] blocks;
}
// debug = abi;
//debug = nullPtrCheck;
debug = nullAllocCheck;
//debug = ctfe;
//debug = MemCpyLocation;
//debug = SetLocation;
debug = GenTemporaryLocation;
//debug = LabelLocation;


enum BlockExitFlags
{
    unconditional_exit = (1 << 0),
    in_condition = (1 << 1),
}

extern (C++) final class BCV(BCGenT) : Visitor
{
    uint unresolvedGotoCount;
    uint breakFixupCount;
    uint continueFixupCount;
    uint fixupTableCount;
    uint uncompiledFunctionCount;
    uint uncompiledConstructorCount;
    uint uncompiledDynamicCastCount;
    uint uncompiledCatchesCount;
    uint processedArgs;
    uint switchStateCount;
    uint currentFunction;
    uint lastLine;
    uint blockExitFlags;
    const (char)[] lastFile;

    BCGenT gen;
    alias gen this;

    // for now!

    BCValue[] arguments;
    BCType[] parameterTypes;

    //    typeof(this)* parent;

    bool processingArguments;
    bool inArgumentProcessing;
    bool processingParameters;
    bool insideArrayLiteralExp;
    uint baseOffsetCount;
    GenExprFlags exprFlags;

    bool IGaveUp;
    /// causes the generator to not emit LineNumbers
    /// used in array literals for example
    bool surpressLine;

    void clear()
    {
        unresolvedGotoCount = 0;
        breakFixupCount = 0;
        continueFixupCount = 0;
        fixupTableCount = 0;
        processedArgs = 0;
        switchStateCount = 0;
        currentFunction = 0;
        baseOffsetCount = 0;
        lastLine = 0;
        lastFile = "";
        blockExitFlags = 0;

        arguments = [];
        parameterTypes = [];

        processingArguments = false;
        inArgumentProcessing = false;
        processingParameters = false;
        insideArrayLiteralExp = false;
        IGaveUp = false;
        discardValue = false;
        ignoreVoid = false;
        surpressLine = false;

        lastConstVd = lastConstVd.init;
        unrolledLoopState = null;
        unrolledLoopStack.unrolledLoopCount = 0;
        switchFixup = null;
        switchState = null;
        me = null;
        lastContinue = typeof(lastContinue).init;

        currentIndexed = BCValue.init;
        retval = BCValue.init;
        assignTo = BCValue.init;
        boolres = BCValue.init;
        _this = BCValue.init;
        closureChain = BCValue.init;

        labeledBlocks.destroy();
        vars.destroy();
        closureVarOffsets.destroy();
    }

    UnrolledLoopState* unrolledLoopState;
    UnrolledLoopStack unrolledLoopStack;
    SwitchState* switchState;
    SwitchFixupEntry* switchFixup;

    FuncDeclaration me;
    bool inReturnStatement;

    UnresolvedGoto[ubyte.max] unresolvedGotos = void;
    BCAddr[ubyte.max] breakFixups = void;
    BCAddr[ubyte.max] continueFixups = void;
    BCScope[16] scopes = void;
    BoolExprFixupEntry[ubyte.max] fixupTable = void;
    UncompiledConstructor[ubyte.max] uncompiledConstructors = void;
    UncompiledDynamicCast[ubyte.max] uncompiledDynamicCasts = void;
    UncompiledFunction[ubyte.max * 8] uncompiledFunctions = void;
    UncompiledCatches[ubyte.max] uncompiledCatches = void;
    SwitchState[16] switchStates = void;
    BCValue[64] baseOffsets = void;

    alias visit = typeof(super).visit;

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

    BCBlock[void* ] labeledBlocks;
    bool ignoreVoid;
    BCValue[void* ] vars;
    uint[void* ] closureVarOffsets;

    /// current this pointer
    BCValue _this;

    /// pointer to a back-linked list of contexts
    /// the link (at offset 0) points to the parent
    BCValue closureChain;

    VarDeclaration lastConstVd;
    typeof(gen.genLabel()) lastContinue;
    BCValue currentIndexed;

    BCValue retval;
    BCValue assignTo;
    BCValue boolres;

    bool discardValue = false;
    uint current_line;

    uint uniqueCounter = 1;

    int getCatchesIndex(Catches* catches)
    {
        foreach(ucc; uncompiledCatches[0 .. uncompiledCatchesCount])
        {
            if (catches == ucc.catches)
            {
                return ucc.fnIdx;
            }
        }

        return 0;
    }

    int getDynamicCastIndex(BCType toType)
    {
        assert(toType.type == BCTypeEnum.Class);
        foreach (dynCast; uncompiledDynamicCasts[0 .. uncompiledDynamicCastCount])
        {
            if (dynCast.toType == toType)
            {
                return dynCast.fnIdx;
            }
        }
        return 0;
    }

    int lookupConstructor(CtorDeclaration cd, BCType type)
    {
        assert(type.type == BCTypeEnum.Class);
        foreach (ctor; uncompiledConstructors[0 .. uncompiledConstructorCount])
        {
            if (ctor.cd == cd && ctor.type == type)
            {
                return ctor.fnIdx;
            }
        }
        return 0;
    }

    import dmd.globals : Loc;
    BCValue addErrorWithMessage(Loc loc, BCValue errorMessage)
    {
        alias add_error_value_prototype = uint delegate (BCValue);
        static if (is(typeof(&gen.addErrorValue) == add_error_value_prototype))
        {
            addErrorValue(errorMessage);
        }

        if (errorMessage.vType == BCValueType.Immediate)
        {
            BCValue t = genTemporary(errorMessage.type);
            Set(t, errorMessage);
        }

        return _sharedCtfeState.addErrorWithMessage(loc, errorMessage);
    }

    extern(D) BCValue addError(const Loc loc, const(char)[] msg, BCValue v1 = BCValue.init, BCValue v2 = BCValue.init, BCValue v3 = BCValue.init, BCValue v4 = BCValue.init)
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

    void Store32AtOffset(BCValue addr, BCValue value, int offset, int line = __LINE__)
    {
        Comment("Store32AtOffset:  " ~ itos(line));
        if (addr.type.type != BCTypeEnum.i32)
            addr = addr.i32;

        if (value.type.type != BCTypeEnum.i32)
            value = value.i32;

        if (!offset)
        {
            debug (nullPtrCheck)
            {
                Store32(addr, value, line);
            }
            else
            {
                Store32(addr, value);
            }
        }
        else
        {
            auto ea = genTemporary(i32Type);
            if (offset > 0)
            {
                Add3(ea, addr, imm32(offset));
            }
            else
            {
                Sub3(ea, addr, imm32(-offset));
            }
            Store32(ea, value);
            destroyTemporary(ea);
        }
    }

    void Load32FromOffset(BCValue value, BCValue addr, int offset, int line = __LINE__)
    {
        if (addr.type.type != BCTypeEnum.i32)
            addr = addr.i32;

        if (value.type.type != BCTypeEnum.i32)
            value = value.i32;

        if (!offset)
        {
            Load32(value, addr);
        }
        else
        {
            auto ea = genTemporary(i32Type);
            if (offset > 0)
            {
                Add3(ea, addr, imm32(offset));
            }
            else
            {
                Sub3(ea, addr, imm32(-offset));
            }
            Load32(value, ea);
            destroyTemporary(ea);
        }
    }

    extern (D) void PrintString (const(char)[] message)
    {
        static if (is(typeof(gen.PrintString(message))))
        {
            gen.PrintString(message);
        }
        else
        printf("PrintString not supported with this backend.");
    }

    debug (MemCpyLocation)
    {
        void MemCpy(BCValue dest, BCValue src, BCValue size, uint line = __LINE__)
        {
            Comment("MemCpy called from: " ~ itos(line));
            gen.MemCpy(dest, src, size);
        }
    }

    debug (nullPtrCheck)
    {
        static if (!is(Loc)) import dmd.lexer : Loc;

        void Load32(BCValue _to, BCValue from, uint line = __LINE__)
        {
            Assert(from.i32, addError(Loc.init,
                    "Load Source may not be null in line: " ~ itos(line)));
            gen.Load32(_to, from);
        }

        void Store32(BCValue _to, BCValue value, uint line = __LINE__)
        {
            Assert(_to.i32, addError(Loc.init,
                    "Store Destination may not be null in line: " ~ itos(line)));
            gen.Store32(_to, value);
        }

    }

    debug (nullAllocCheck)
    {
        void Alloc(BCValue result, BCValue size, BCType type = BCType.init, uint line = __LINE__)
        {
            assert(size.vType != BCValueType.Immediate || size.imm32 != 0, "Null Alloc detected in line: " ~ itos(line));
            Comment("Alloc From: " ~ itos(line) ~  " forType: " ~ _sharedCtfeState.typeToString(type));
            gen.Alloc(result, size.u32);
        }
    }

    debug (LabelLocation)
    {
        import std.stdio;
        typeof(gen.genLabel()) genLabel(uint line = __LINE__)
        {
            auto l = gen.genLabel();
            Comment("genLabel from: " ~ itos(line));
            return l;
        }
    }

    debug (SetLocation)
    {
        import std.stdio;
        void Set(BCValue lhs, BCValue rhs, size_t line = __LINE__)
        {
            writeln("Set(", lhs.toString, ", ", rhs.toString, ") called at: ", line);
            gen.Set(lhs, rhs);
        }
    }

    debug (GenTemporaryLocation)
    {
        BCValue genTemporary(BCType type, int line = __LINE__)
        {
            Comment("genTemporary from:" ~ itos(line));
            return gen.genTemporary(type);
        }
    }

    debug (DestroyTemporaryLocation)
    {
        void destroyTemporary(BCValue tmp, int line = __LINE__)
        {
            Comment("destroyTemporary from:" ~ itos(line));
            return gen.destroyTemporary(tmp);
        }
    }

    alias CompFnType = extern(D) void delegate(BCValue result, BCValue lhs, BCValue rhs);

    extern (D) typeof(gen.beginCndJmp()) If(BCValue a, CompFnType comp,  BCValue b)
    {
        comp(BCValue.init, a, b);
        auto cndJmp = beginCndJmp();
        return cndJmp;
    }

    void EndIf(typeof(gen.beginCndJmp()) cndJmp)
    {
        endCndJmp(cndJmp, genLabel());
    }

    typeof(gen.beginJmp()) Else(typeof(gen.beginCndJmp()) ifRet)
    {
        auto afterElseJmp = beginJmp();
        endCndJmp(ifRet, genLabel());
        return afterElseJmp;
    }

    void EndElse(typeof(gen.beginJmp()) afterElseJmp)
    {
        endJmp(afterElseJmp, genLabel());
    }

    /// sets a memory location to a value
    void SetMem(BCValue addr, BCValue value)
    {
        auto valueSize = _sharedCtfeState.size(value.type, true);

        if (!valueSize)
        {
            bailout("zero size value passed to setMem"  ~ _sharedCtfeState.typeToString(value.type));
            return ;
        }
        if (isBasicBCType(value.type) && !isPassedByPointer(value.type.type))
            StoreBasicType(addr, value, value.type.type);
        else
            MemCpy(addr.i32, value.i32, imm32(valueSize));
    }

    void expandSliceBy(BCValue slice, BCValue expandBy)
    {
        assert(slice && slice.type.type == BCTypeEnum.Slice);
        assert(expandBy);

        auto length = getLength(slice);
        auto newLength = genTemporary(i32Type);
        Add3(newLength, length, expandBy);
        expandSliceTo(slice, newLength);
        destroyTemporary(newLength);
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
        destroyTemporary(effectiveSize);
    }

    void expandSliceTo(BCValue slice, BCValue newLength)
    {
        Comment("SliceExpansion");
        auto sliceType = slice.type.type;
        auto newLengthType = newLength.type.type;
        if((sliceType != BCTypeEnum.Slice && sliceType != BCTypeEnum.string8) && (newLengthType != BCTypeEnum.i32 && newLengthType == BCTypeEnum.i64))
        {
            bailout("We only support expansion of slices by i32, not: " ~ enumToString(sliceType) ~ " by " ~ enumToString(newLengthType));
            return ;
        }
        debug(nullPtrCheck)
        {
            Assert(slice.i32, addError(lastLoc, "expandSliceTo: arrPtr must not be null"));
        }
        auto oldBase = getBase(slice);
        auto oldLength = getLength(slice);
        scope (exit)
        {
            destroyTemporary(oldBase);
            if (oldLength.vType != BCValueType.Immediate)
            {
                destroyTemporary(oldLength);
            }
        }

        auto newBase = genTemporary(i32Type);
        scope(exit) destroyTemporary(newBase);
        auto effectiveSize = genTemporary(i32Type);

        auto elementType = _sharedCtfeState.elementType(slice.type);
        if(!elementType.type)
        {
            bailout("we could not get the elementType of " ~ _sharedCtfeState.typeToString(slice.type));
            return ;
        }
        auto elementSize = _sharedCtfeState.size(elementType);

        Mul3(effectiveSize, newLength, imm32(elementSize));
        Alloc(newBase, effectiveSize, slice.type);
        setBase(slice, newBase);
        setLength(slice, newLength);

        // If we are trying to expand a freshly created slice
        // we don't have to copy the old contents
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

    extern (D) void bailout(bool value, lazy const(char)[] message, uint line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {
        if (value)
        {
            bailout(message, line, pfn);
        }
    }

    extern (D) void excused_bailout(const(char)[] message, uint line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {

        const fnIdx = _sharedCtfeState.getFunctionIndex(me);
        IGaveUp = true;
        if (fnIdx)
            static if (is(BCFunction))
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(null);
            }

    }

    extern (D) void bailout(const(char)[] message, uint line = __LINE__, string pfn = __PRETTY_FUNCTION__)
    {
        IGaveUp = true;
        import dmd.globals;
        // global.newCTFEGaveUp = true;
        const fnIdx = _sharedCtfeState.getFunctionIndex(me);

        enum headLn = 58;
        if (pfn.length > headLn)
        {
            import std.string : indexOf;
            auto offset = 50;
            auto begin = pfn[offset .. $].indexOf('(') + offset + 1;
            auto end = pfn[begin .. $].indexOf(' ') + begin;
            pfn = pfn[begin .. end] ~ "\0";
        }

        if (fnIdx)
            static if (is(BCFunction))
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(null);
            }
        debug (ctfe)
        {
//            assert(0, "bail out on " ~ pfn ~ " (" ~ itos(line) ~ "): " ~ message);
        }
        else
        {
            import core.stdc.stdio;
            static if (bailoutMessages)
                printf("bail out on %s (%d): %s -- (srcLine: %d)\n", pfn.ptr, line, message.ptr, lastLine);
        }
    }

    extern (D) void File(const (char)[] filename)
    {
        //Maybe we could hash the filename
        //on the other hand hashing is as expensive as comparing
        //if strings are not interned
        if (filename.length && filename != lastFile)
        {
            lastFile = filename;
            static if (is(typeof(gen.File(string.init))))
            {
                gen.File(cast(string)filename);
            }
            else
            {
                gen.Comment("File: " ~ cast(string)filename);
            }
        }
    }

    void Line(uint line)
    {
        if (!surpressLine && line && line != lastLine)
        {
            lastLine = line;
            static if (is(typeof(gen.Line(uint.init))))
            {
                gen.Line(line);
            }
            else
            {
                gen.Comment("Line " ~ itos(line));
            }
        }

    }

    void IndexedScaledLoad32(BCValue _to, BCValue from, BCValue index, const int scale, int line = __LINE__)
    {
        assert(_to.type.type == BCTypeEnum.i32, "_to has to be an i32");
        assert(from.type.type == BCTypeEnum.i32, "from has to be an i32");
        assert(index.type.type == BCTypeEnum.i32 || index.type.type == BCTypeEnum.u32, "index has to be an i32. not: " ~ index.type.type.enumToString);

        static if (is(typeof(gen.IndexedScaledLoad32) == function)
                && is(typeof(gen.IndexedScaledLoad32(
                        BCValue.init, BCValue.init, BCValue.init, int.init
                )) == void)
                && isValidIndexScalar(scale))
        {
            gen.IndexedScaledLoad32(_to, from, index, scale);
        }

        else
        {
            Comment("ScaledLoad from " ~ itos(line));

            auto ea = genTemporary(i32Type);
            Mul3(ea, index, imm32(scale));
            Add3(ea, ea, from);
            Load32(_to, ea);
            destroyTemporary(ea);
        }
    }

    void IndexedScaledStore32(BCValue _to, BCValue from, BCValue index, const int scale, int line = __LINE__)
    {
        assert(_to.type.type == BCTypeEnum.i32, "_to has to be an i32");
        assert(from.type.type == BCTypeEnum.u32 || from.type.type == BCTypeEnum.i32, "from has to be an i32");
        assert(index.type.type == BCTypeEnum.u32, "index has to be an i32");

        static if (is(typeof(gen.IndexedScaledStore32) == function)
            && is(typeof(gen.IndexedScaledStore32(
                        BCValue.init, BCValue.init, BCValue.init, int.init
                        )) == void)
            && isValidIndexScalar(scale))
        {
            gen.IndexedScaledStore32(_to, from, index, scale);
        }

        else
        {
            Comment("ScaledStore from " ~ itos(line));

            auto ea = genTemporary(i32Type);
            Mul3(ea, index, imm32(scale));
            Add3(ea, ea, _to);
            Store32(ea, from);
            destroyTemporary(ea);
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
            auto offset = genTemporary(i32Type);
            scope(exit) destroyTemporary(offset);

            auto len1 = getLength(rhs);
            auto len2 = getLength(lhs);
            scope(exit)
            {
                if (len1.vType != Immediate)
                {
                    destroyTemporary(len1);
                }
                if (len2.vType != Immediate)
                {
                    destroyTemporary(len2);
                }
            }
            Eq3(result, len1, len2);

            auto ptr1 = getBase(lhs);
            auto ptr2 = getBase(rhs);
            Set(offset, len1);

            auto e1 = genTemporary(i32Type);
            auto e2 = genTemporary(i32Type);
            scope(exit)
            {
                destroyTemporary(e1);
                destroyTemporary(e2);
            }
            auto LbeginLoop = genLabel();
            auto is_false = beginCndJmp(result);
            auto is_at_end = beginCndJmp(offset);
            Sub3(offset, offset, imm32(1));

            Load32(e1, ptr1);
            Load32(e2, ptr2);
            Eq3(result, e1, e2);
            Jmp(LbeginLoop);
            auto LendLoop = genLabel();
            endCndJmp(is_false, LendLoop);
            endCndJmp(is_at_end, LendLoop);
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

        if (me.vthis
            // make sure vthis is not a void pointer
            // this can happen with closures
            && !(me.vthis.type.ty == Tpointer
                && me.vthis.type.nextOf().ty == Tvoid)
        )
        {
            _this = genParameter(toBCType(me.vthis.type), "thisPtr");
            setVariable(me.vthis, _this);
        }

        // BUG? checking  me.isClassDeclaration
        // is need because we are casting a ClassDecl
        // into a FuncDecl, for ctor generation

        if ((!me.isClassDeclaration) && me.isNested())
        {
            closureChain = genParameter(i32Type, "closureChain");
            // D's closure has no type
            // therefore use generic pointer
        }
    }

    void beginArguments()
    {
        processingArguments = true;
        inArgumentProcessing = true;
    }

    void endArguments()
    {
        processedArgs = 0;
        processingArguments = false;
        inArgumentProcessing = false;
    }

    BCValue getVariable(VarDeclaration vd, VarExp ve = null)
    {
        if (vd.storage_class & STC.static_ && !(vd.storage_class & STC.immutable_))
        {
            bailout("cannot handle static variables");
            return BCValue.init;
        }

        if (auto value = (cast(void*) vd) in vars)
        {
            if (vd.storage_class & STC.ref_ && !value.heapRef)
            {
             //   assert(0, "We got a ref and the heapRef is not set this is BAD!");
            }
            return *value;
        }
        else if ((vd.isDataseg() || vd.storage_class & STC.manifest) && !vd.isCTFE() && vd._init)
        {

            if (vd == lastConstVd)
                bailout("circular initialisation apperantly");

            lastConstVd = vd;
            if (auto ci = vd.getConstInitializer())
            {
                lastConstVd = null;
                //printf("generating an static argument value for: %s\n", ci.toChars());
                return genArg(ci);
                //return genExpr(ci, "Const Initializer");
            }

            return BCValue.init;
        }
        else if (auto cv = searchInParent(me, vd))
        {
            Comment("closureVarLoad '" ~ cast(string)vd.ident.toString() ~ "'  for Level: " ~ itos(cv.depth));
            auto cvp = genTemporary(i32Type);
            scope(exit) destroyTemporary(cvp);

            assert(closureChain);
            Assert(closureChain, addError(ve ? ve.loc : vd.loc, "no closure-chain-pointer is null"));
            Set(cvp, closureChain);

            foreach(level; 0 .. cv.depth)
            {
                Load32(cvp, cvp);
            }

            Add3(cvp, cvp, imm32(cv.offset));

            auto bctype = toBCType(vd.type);
            BCValue var = genLocal(bctype, cast(string)vd.ident.toString);

            // because a struct is represented via a ptr into the closure memory
            // we must make the created local point to that
            if (isPassedByPointer(bctype.type))
            {
                Set(var.i32, cvp.i32);
            }
            else
            {
                var.heapRef = BCHeapRef(cvp);
                LoadFromHeapRef(var);
            }

            setVariable(vd, var);
            return var;
        }
        else
        {
            return BCValue.init;
        }
    }

    BCValue closureRef(uint closureOffset)
    {
        bailout("closureRef unsupported");
        return BCValue.init;
    }

    void doCat(ref BCValue result, BCValue lhs, BCValue rhs)
    {
        auto lhsBaseType = _sharedCtfeState.elementType(lhs.type);
        const elemSize = _sharedCtfeState.size(lhsBaseType);

        if (!elemSize)
        {
            bailout("Type has no Size: " ~ _sharedCtfeState.typeToString(lhsBaseType));
            result = BCValue.init;
            return ;
        }

        static if (is(typeof(Cat3) == function)
                && is(typeof(Cat3(BCValue.init, BCValue.init, BCValue.init, uint.init)) == void))
        {
            // due to limitations of the opcode-format we can only issue this
            // if the elemSize fits in one byte ...

            if (!is(BCgen) || elemSize < 255)
            {
                Cat3(result, lhs, rhs, elemSize);
                if (!is(BCGen) || elemSize < 255) return ;
            }
        }

        // we go here if the concat could not be done by a cat3 instruction
        {
            auto lhsOrRhs = genTemporary(i32Type);
            Or3(lhsOrRhs, lhs.i32, rhs.i32);

            // lhs == result happens when doing e = e ~ x;
            // in that case we must not set the result to zero
            if (lhs != result)
                Set(result.i32, imm32(0));

            auto CJisNull = beginCndJmp(lhsOrRhs);

            auto lhsLength = getLength(lhs);
            auto rhsLength = getLength(rhs);
            auto lhsBase = getBase(lhs);
            auto rhsBase = getBase(rhs);

            auto effectiveSize = genTemporary(i32Type);
            auto newLength = genTemporary(i32Type);
            auto newBase = genTemporary(i32Type);

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
        return (e && (e.op == TOK.andAnd || e.op == TOK.orOr));
    }

    extern (D) BCValue genExpr(Expression expr, string debugMessage = null, uint line = __LINE__)
    {
        return genExpr(expr, GenExprFlags.None, debugMessage, line);
    }

    extern (D) BCValue genExpr(Expression expr, GenExprFlags flags, string debugMessage = null, uint line = __LINE__)
    {
        auto oldExprFlags = exprFlags;
        exprFlags = flags;
        if (!expr)
        {
            // import core.stdc.stdio; printf("Calling genExpr(null) from: %d\n", line); //DEBUGLINE
            return BCValue.init;
        }

        auto oldRetval = retval;
        import dmd.asttypename;
        // import std.stdio; static string currentIndent = ""; writeln(currentIndent, "genExpr(" ~ expr.astTypeName ~ ") from: ", line, (debugMessage ? " \"" ~ debugMessage ~ "\" -- " : " -- ") ~ expr.toString); currentIndent ~= "\t"; scope (exit) currentIndent = currentIndent[0 .. $-1]; //DEBUGLINE

        if (processingArguments)
        {
            assert(0, "genExpr must no longer be called when processing arguments");
        }
        else
        {
            const oldFixupTableCount = fixupTableCount;
            if (expr)
                expr.accept(this);
            if (isBoolExp(expr) && !(flags & GenExprFlags.customBoolFixup))
            {
                if (assignTo)
                {
                    retval = assignTo.i32;
                }
                else
                {
                    retval = boolres = boolres ? boolres : genTemporary(i32Type);
                }

                if (expr.op == TOK.andAnd)
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
        exprFlags = oldExprFlags;

        return ret;
    }

    static if (is(BCFunction) && is(typeof(_sharedCtfeState.functionCount)))
    {
        void addUncompiledFunction(FuncDeclaration fd, int* fnIdxP, bool mayFail = false)
        {
            // printf("Adding uncompiled function \"%s\"\n", fd.toPrettyChars()); // debugline
            assert(*fnIdxP == 0, "addUncompiledFunction has to be called with *fnIdxP == 0");
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

            if (fd.fbody)
            {
                const fnIdx = ++_sharedCtfeState.functionCount;
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd);
                uncompiledFunctions[uncompiledFunctionCount] = UncompiledFunction(fd, fnIdx);
                uncompiledFunctions[uncompiledFunctionCount].mayFail = mayFail;
                ++uncompiledFunctionCount;
                *fnIdxP = fnIdx;
            }
            else
            {
                if (fd.isVirtualMethod())
                {
                    const fnIdx = ++_sharedCtfeState.functionCount;
                    _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd);
                    uncompiledFunctions[uncompiledFunctionCount] = UncompiledFunction(fd, fnIdx, true, "Calling Abstract Interface Method");
                    uncompiledFunctions[uncompiledFunctionCount].mayFail = mayFail;
                    ++uncompiledFunctionCount;
                    *fnIdxP = fnIdx;
                }
                else
                {
                    bailout("Null-Body: probably builtin: " ~ fd.toString);
                }
            }
        }

        void addUncompiledConstructor(CtorDeclaration ctor, BCType type, int *cIdxP)
        {
            if (ctor)
                ctor.functionSemantic3();

            if (uncompiledFunctionCount >= uncompiledFunctions.length - 64)
            {
                bailout("UncompiledFunctions overflowed");
                return ;
            }
            //printf("UncompiledConstructor: %s\n", ctor.toString().ptr); //debugline

            const fnIdx = ++_sharedCtfeState.functionCount;
            _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) ctor);
            uncompiledConstructors[uncompiledConstructorCount] =
                UncompiledConstructor(ctor, type, fnIdx);
            ++uncompiledConstructorCount;
            *cIdxP = fnIdx;
        }


        void addDynamicCast(BCType toType, int *cIdxP)
        {
            if (uncompiledFunctionCount >= uncompiledFunctions.length - 64)
            {
                bailout("UncompiledFunctions overflowed");
                return ;
            }

            const fnIdx = ++_sharedCtfeState.functionCount;
            _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) uncompiledDynamicCastCount);
            uncompiledDynamicCasts[uncompiledDynamicCastCount] =
                UncompiledDynamicCast(toType, fnIdx);
            ++uncompiledDynamicCastCount;
            *cIdxP = fnIdx;
        }
    }
    else
    {
        void addUncompiledFunction(FuncDeclaration fd, int *fnIdxP)
        {
            assert(0, "We don't support Functions!\nHow do you expect me to add a function?");
        }

        void addUncompiledConstructor(CtorDeclaration ctor, BCType type, int *cIdxP)
        {
            assert(0, "We don't support Functions!\nHow do you expect me to add a constructor?");
        }

        void addDynamicCast(BCType toType, int *cIdxP)
        {
            assert(0, "We don't support Functions!\nHow do you expect me to add a dynamicCast?");
        }
    }

    void allocateAndLinkClosure(FuncDeclaration fd)
    {
        assert(fd.closureVars.dim);

        uint closureChainSize = 4;

        foreach(ref v;fd.closureVars)
        {
            setClosureVarOffset(v, closureChainSize);
            auto type = toBCType(v.type);

            closureChainSize += _sharedCtfeState.size(type, true);
        }

        BCValue newClosure = genLocal(i32Type, "newClosure");
        Alloc(newClosure, imm32(closureChainSize));

        if (fd.isNested())
        {
            assert(closureChain);
            auto pfd = fd.toParent2().isFuncDeclaration();
            if (pfd && pfd.hasNestedFrameRefs())
            {
                Assert(closureChain, addError(lastLoc, "Missing parent closure-chain"));
            }

            Store32(newClosure, closureChain);
        }
        else
        {
            if (!closureChain)
            {
                closureChain = newClosure;
            }
        }
        Set(closureChain, newClosure);
    }


    void compileUncompiledConstructors()
    {
        foreach(ref uc;uncompiledConstructors[0 .. uncompiledConstructorCount])
        {
            if (!uc.cd)
                compileUncompiledDefaultConstructor(uc);
            else
            {
                compileUncompiledFunction(uc.cd, uc.fnIdx, false, &uc.type);
            }
        }
        uncompiledConstructorCount = 0;
    }

    void compileUncompiledDefaultConstructor(UncompiledConstructor uc)
    {
        import dmd.identifier : Identifier;
        __gshared FuncDeclaration dummy_fd;
        if (!dummy_fd)
        {
            dummy_fd = new FuncDeclaration(Loc.initial, Loc.initial, Identifier.init, 0, Type.init);
        }

        assert(uc.cd is null, "This is _only_ for DefaultConstructors");
        {
            // if we are building a ctor it might happen that it is null
            // when the class has no construcor defined
            // however we need to safe a vtblPtr at the very least
            // so let's do just that!

            assert(uc.type.type == BCTypeEnum.Class && uc.type.typeIndex);
            const tIdx = uc.type.typeIndex - 1;
            auto bcClass = &_sharedCtfeState.classTypes[tIdx];
            auto cdtp = _sharedCtfeState.classDeclTypePointers[tIdx];

            // now we need to ensure that our parent has it's default ctor set

            static if (is(BCGen))
            {
                auto osp = sp;
            }
            vars.destroy();
            beginParameters();
                auto p1 = genParameter(i32Type, "thisPtr");
                // the following is a hack to fake us setting a me.ptr
                // which we need for endParameters
                auto oldme = me;
                me = dummy_fd;
            endParameters();
                me = oldme;
            beginFunction(uc.fnIdx - 1, cast(void*) null);
            // printf("BuildingCtor for: %s\n", cdtp.toString().ptr);
                // the first thing we need to do is to call, the parent default ctor.
            if (bcClass.parentIdx)
            {
                auto pClass = _sharedCtfeState.classTypes[bcClass.parentIdx - 1];
                auto pCd = _sharedCtfeState.classDeclTypePointers[bcClass.parentIdx - 1];
                auto fnIdx = pClass.defaultCtorIdx;
                if (fnIdx)
                {
                    Call(p1, imm32(fnIdx), [p1]);
                }
                else
                {
                    printf("default ctor for parent unknown parent: %s this: %s\n", pCd.toChars(), cdtp.toChars());
//                        bailout("default parent ctor unknown");
                }
            }
            // here 

            Store32AtOffset(p1, imm32(bcClass.vtblPtr), ClassMetaData.VtblOffset);
            Store32AtOffset(p1, imm32(uc.type.typeIndex), ClassMetaData.TypeIdIdxOffset);
            foreach(f;cdtp.fields)
            {
                // go through the fields and if there is a value store it at the appropriate offset
                if (f._init)
                {
                    const fInfo = getFieldInfo(uc.type, f);
                    auto initExp = genExpr(f._init.isExpInitializer().exp);
                    auto fieldAddr = genTemporary(i32Type);
                    Add3(fieldAddr, p1, imm32(fInfo.offset));
                    SetMem(fieldAddr, initExp);
                }
            }
            Ret(p1);
            endFunction();
            lastFile = null;
            bcClass.defaultCtorIdx = uc.fnIdx;

            static if (is(BCGen))
            {
                _sharedCtfeState.functions[uc.fnIdx - 1] = BCFunction(cast(void*) null,
                    uc.fnIdx, BCFunctionTypeEnum.Bytecode,
                    cast(ushort) (1), osp.addr);
                _sharedCtfeState.functions[uc.fnIdx - 1].byteCode.length = ip;
                _sharedCtfeState.functions[uc.fnIdx - 1].byteCode[0 .. ip]
                    = byteCodeArray[0 .. ip];

            }
        }
    }

    void compileUncompiledFunctions()
    {
        uint lastUncompiledFunction;

    LuncompiledFunctions :
        foreach (uf;uncompiledFunctions[lastUncompiledFunction .. uncompiledFunctionCount])
        {
            if (uf.dummyErrorFunctionMessage !is null)
            {
                auto loc = uf.fd ? uf.fd.loc : Loc.init;
                beginFunction(uf.fn - 1, cast(void*)me);
                {
                    Assert(imm32(0), addError(loc, uf.dummyErrorFunctionMessage));
                }
                endFunction();
                lastFile = null;
            }
            else if (uf.fd)
                compileUncompiledFunction(uf.fd, uf.fn, uf.mayFail, null);

            lastUncompiledFunction++;
        }

        if (uncompiledFunctionCount > lastUncompiledFunction)
            goto LuncompiledFunctions;

        clearArray(uncompiledFunctions, uncompiledFunctionCount);
        // not sure if the above clearArray does anything
        uncompiledFunctionCount = 0;
    }

    void compileUncompiledFunction(FuncDeclaration fd, int fnIdx,
        bool mayFail, BCType* forCtor)
    {
        assert(fd);
        {
            if (_blacklist.isInBlacklist(fd.ident))
            {
                bailout("Bail out on blacklisted: " ~ fd.ident.toString());
                return ;
            }

            if (forCtor)
            {
                assert(forCtor.type == BCTypeEnum.Class && forCtor.typeIndex);
            }

            //assert(!me, "We are not clean!");
            me = fd;

            vars.destroy();
            beginParameters();
            auto parameters = me.parameters;
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

            File(fromStringz(me.loc.filename));
            Line(me.loc.linnum);

            beginFunction(fnIdx - 1, cast(void*)me);

            if (me.closureVars.dim)
                allocateAndLinkClosure(me);


            if (forCtor)
            {
                const bcClass = _sharedCtfeState.classTypes[forCtor.typeIndex - 1];
                if (!_this) Comment("There's no this here");
                Store32AtOffset(_this.i32, imm32(bcClass.vtblPtr), ClassMetaData.VtblOffset);
                Store32AtOffset(_this.i32, imm32(forCtor.typeIndex), ClassMetaData.TypeIdIdxOffset);
            }


            me.fbody.accept(this);

            static if (is(BCGen))
            {
                auto osp = sp;
            }

            if (fd.type.nextOf.ty == Tvoid)
            {
                // insert a dummy return after void functions because they can omit a returnStatement
                Ret(bcNull);
            }
            File(fromStringz(me.endloc.filename));
            Line(me.endloc.linnum);
            Comment("Function ends here ...");
            endFunction();
            lastFile = null;

            if (IGaveUp)
            {
                if (!forCtor && mayFail)
                {
                    if (insideFunction)
                    {
                        Assert(imm32(0), addError(fd.loc, "CTFE ABORT IN : " ~ fd.toString ~ ":" ~ itos(lastLine)));
                    }
                    IGaveUp = false;
                }
                else
                {
                    bailout("A called function bailed out: " ~ fd.toString);
                    return ;
                }
            }

            static if (is(BCGen))
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd,
                    fnIdx, BCFunctionTypeEnum.Bytecode,
                    cast(ushort) (parameters ? parameters.dim : 0), osp.addr);
                _sharedCtfeState.functions[fnIdx - 1].byteCode.length = ip;
                _sharedCtfeState.functions[fnIdx - 1].byteCode[0 .. ip]
                    = byteCodeArray[0 .. ip];
            }
            else
            {
                _sharedCtfeState.functions[fnIdx - 1] = BCFunction(cast(void*) fd);
            }
            clear();
        }
    }

    void compileUncompiledDynamicCasts()
    {
        foreach(udc;uncompiledDynamicCasts[0 .. uncompiledDynamicCastCount])
        {
            assert(udc.toType.type == BCTypeEnum.Class,
                "Either " ~ udc.toType.toString ~ "is not a class");
            auto toClass = _sharedCtfeState.classTypes[udc.toType.typeIndex - 1];

            static if (is(BCGen))
            {
                auto osp = sp;
            }

            auto p1 = genParameter(i32Type, "dyncast_this");
            beginFunction(udc.fnIdx - 1, null);
            {
                auto rv = genTemporary(i32Type);
                auto vtblPtr = genTemporary(i32Type);
                auto vtblPtrAddr = genTemporary(i32Type);
                auto found = genTemporary(i32Type);

                Set(rv, p1.i32);

                if (ClassMetaData.VtblOffset)
                {
                    Add3(vtblPtrAddr, p1.i32, imm32(ClassMetaData.VtblOffset));
                }
                else
                {
                    Set(vtblPtrAddr, p1.i32);
                }

                auto LbeginLoop = genLabel();
                {
                    auto nullVtblCJ = beginCndJmp(vtblPtrAddr);
                    Load32(vtblPtr.i32, vtblPtrAddr.i32);
                    Eq3(found, vtblPtr, imm32(toClass.vtblPtr));
                    auto foundVtblPtrCJ = beginCndJmp(found, true);
                    {
                        Set(vtblPtrAddr, vtblPtr);
                    }

                    Jmp(LbeginLoop);
                    auto LRetNull = genLabel();
                    {
                        Set(rv, imm32(0));
                    }
                    endCndJmp(nullVtblCJ, LRetNull);
                    auto LRet = genLabel();
                    {
                        Ret(rv);
                    }
                    endCndJmp(foundVtblPtrCJ, LRet);
                }
            }
            endFunction();
            lastFile = null;

            static if (is(BCGen))
            {
                _sharedCtfeState.functions[udc.fnIdx - 1] = BCFunction(cast(void*) null,
                    udc.fnIdx, BCFunctionTypeEnum.Bytecode,
                    cast(ushort) (1), osp.addr);
                _sharedCtfeState.functions[udc.fnIdx - 1].byteCode.length = ip;
                _sharedCtfeState.functions[udc.fnIdx - 1].byteCode[0 .. ip]
                    = byteCodeArray[0 .. ip];
                sp = osp;
            }

        }

        uncompiledDynamicCastCount = 0;
    }

    static int findFieldIndexByName(ClassDeclaration cd, VarDeclaration v)
    {
        int result = -1;
        int fieldsBefore = 0;
        int relativeFieldIndex = -1;

        while(cd)
        {
            foreach(i, f; cd.fields)
            {
                if (v == f)
                {
                    relativeFieldIndex = cast(int)i;
                    break;
                }
            }

            if (relativeFieldIndex >= 0)
            {
                for(cd = cd.baseClass;cd;cd = cd.baseClass)
                {
                    fieldsBefore += cd.fields.dim;
                }
                result = fieldsBefore + relativeFieldIndex;
                break;
            }
            cd = cd.baseClass;
        }

        return result;
    }

    FieldInfo getFieldInfo(BCType t, VarDeclaration vd)
    {
        FieldInfo fInfo;

        if (t.type == BCTypeEnum.Struct)
        {
            const ti = t.typeIndex;
            if (!ti || ti > _sharedCtfeState.structCount)
            {
                bailout("can't get struct-type ti: " ~ itos(ti) ~ " structCount: " ~ itos(_sharedCtfeState.structCount));
                return fInfo;
            }
            auto sd = _sharedCtfeState.structDeclTypePointers[ti - 1];
            import dmd.ctfeexpr : findFieldIndexByName;
            auto idx = findFieldIndexByName(sd, vd);
            if (idx != -1)
            {
                auto _struct = _sharedCtfeState.structTypes[ti - 1];
                fInfo.index = idx;
                fInfo.offset = _struct.offset(idx);
                fInfo.type = _struct.memberTypes[idx];
            }
            else
                assert(0, "Field could not be found");
        }
        else if (t.type == BCTypeEnum.Class)
        {
            const ti = t.typeIndex;
            if (!ti || ti > _sharedCtfeState.classCount)
            {
                bailout("can't get class-type ti: " ~ itos(ti) ~ " classCount: " ~ itos(_sharedCtfeState.classCount));
                return fInfo;
            }
            auto cd = _sharedCtfeState.classDeclTypePointers[ti - 1];
            auto idx  = findFieldIndexByName(cd, vd);
            if (idx != -1)
            {
                auto _class = _sharedCtfeState.classTypes[ti - 1];
                fInfo.index = idx;
                fInfo.offset = _class.offset(idx);
                fInfo.type = _class.memberTypes[idx];
            }
            else
                assert(0, "Field could not be found");

        }

        // import std.stdio : writeln; debug { if (!__ctfe) {writeln("fInfo: ", fInfo, "vd: ", vd.toString()); } } //DEBUGLINE 
        return fInfo;
    }

    override void visit(FuncDeclaration fd)
    {
        lastLoc = fd.loc;

        import dmd.identifier;

        assert(!me || me == fd);
        me = fd;

        //HACK this filters out functions which I know produce incorrect results
        //this is only so I can see where else are problems.
        if (_blacklist.isInBlacklist(fd.ident))
        {
            bailout("Bailout on blacklisted");
            return ;
        }
        import std.stdio;
        if (insideFunction)
        {
            auto fnIdx = _sharedCtfeState.getFunctionIndex(fd);
            addUncompiledFunction(fd, &fnIdx);
            return ;
        }

        //writeln("going to eval: ", fd.toString);
        File(fromStringz(fd.loc.filename));
        Line(fd.loc.linnum);
        if (auto fbody = fd.fbody.isCompoundStatement)
        {
            vars.destroy();
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
            assert(me, "We did not set ourselves");
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

            if (fd.isVirtualMethod())
            {
                assert(fd.vtblIndex != -1, "virtual method with vtblIdx of -1, seems invlaid -- " ~ fd.toString);
            }

            beginFunction(fnIdx - 1, cast(void*)fd);

            //TODO it seems that hasNstedFrameRefs does not work transitively!
            if (fd.closureVars.dim)
                allocateAndLinkClosure(fd);

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

            File(fromStringz(fd.endloc.filename));
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
                return ;
            }

            static if (is(typeof(_sharedCtfeState.functions)))
            {
                //FIXME IMPORTANT PERFORMANCE!!!
                // get rid of dup!

                auto myPTypes = parameterTypes.dup;
                auto myArgs = arguments.dup;
static if (is(BCGen))
{
                auto myCode = byteCodeArray[0 .. ip];
                auto myIp = ip;
}
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
                            cast(ushort) parameterTypes.length, osp2);
                        _sharedCtfeState.functions[fnIdx - 1].byteCode.length = myIp;
                        _sharedCtfeState.functions[fnIdx - 1].byteCode[0 .. myIp] =
                            byteCodeArray[0 .. myIp];
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
        else
            assert(0, "fbody is null");
    }

    override void visit(FuncExp e)
    {
        auto fIndex = _sharedCtfeState.getFunctionIndex(e.fd);
        if (!fIndex)
        {
            addUncompiledFunction(e.fd, &fIndex);
        }
        auto ptr = genTemporary(toBCType(e.type));
        Alloc(ptr, imm32(4), ptr.type);
        Store32(ptr, imm32(fIndex));
        retval = ptr;
        printf("FuncExp:: %s", e.fd.fbody.toChars());
    }

    override void visit(DeleteExp e)
    {
    }

    override void visit(BinExp e)
    {
        lastLoc = e.loc;

        File(fromStringz(e.loc.filename));
        Line(e.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("Called visit(BinExp) %s ... \n\tdiscardReturnValue %d",
                e.toString, discardValue);
            writefln("(BinExp).Op: %s", e.op.enumToString);

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

        case TOK.plusPlus:
            {
                const oldDiscardValue = discardValue;
                discardValue = false;
                auto expr = genExpr(e.e1);
                if ((!canWorkWithType(expr.type)) || (!canWorkWithType(retval.type)))
                {

                    bailout("++ only i32 is supported not expr: " ~ enumToString(expr.type.type) ~ "retval: " ~ enumToString(retval.type.type) ~ " -- " ~ e.toString);
                    return ;
                }

                assert(expr.vType != BCValueType.Immediate,
                    "++ does not make sense on an Immediate Value");

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
                else if (expr.type.type.anyOf(smallIntegers))
                {
                    expr = expr.i32;
                    Add3(expr, expr, imm32(1));
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
        case TOK.minusMinus:
            {
                const oldDiscardValue = discardValue;
                discardValue = false;
                auto expr = genExpr(e.e1);
                if (!canWorkWithType(expr.type) || !canWorkWithType(retval.type))
                {
                    bailout("-- only i32 is supported not " ~ enumToString(expr.type.type));
                    return ;
                }
                assert(expr.vType != BCValueType.Immediate,
                    "-- does not make sense on an Immediate Value");

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
        case TOK.equal, TOK.notEqual:
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
                    if (e.op == TOK.notEqual)
                        Eq3(retval.i32, retval.i32, imm32(0));
                }
                else if (canHandleBinExpTypes(toBCType(e.e1.type).type, toBCType(e.e2.type).type))
                {
                    goto case TOK.add;
                }
            }
            break;
        case TOK.identity:
            {
                auto lhs = genExpr(e.e1);
                auto rhs = genExpr(e.e2);
                if (!lhs || !rhs)
                {
                    bailout("could not gen lhs or rhs for " ~ e.toString);
                   return ;
                }

                Eq3(retval.i32, lhs.i32, rhs.i32);
            }
            break;
        case TOK.notIdentity:
            {
                auto lhs = genExpr(e.e1);
                auto rhs = genExpr(e.e2);
                if (!lhs || !rhs)
                {
                    bailout("could not gen lhs or rhs for " ~ e.toString);
                    return ;
                }

                Neq3(retval.i32, lhs.i32, rhs.i32);
            }
            break;
        case TOK.question:
            {
        Comment(": ? begin ");
                auto ce = cast(CondExp) e;
                auto cond = genExpr(ce.econd);
                debug (ctfe)
                    assert(cond);
                    else if (!cond)
                    {
                        bailout("Conditional in ? : could not be evaluated");
                        return ;
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
        case TOK.concatenate:
            {
                auto lhs = genExpr(e.e1, "Cat lhs");
                auto rhs = genExpr(e.e2, "Cat rhs");

                assert(retval, "Cat needs a retval!");

                if (!lhs || !rhs)
                {
                    bailout("bail out because either lhs or rhs for ~ could not be generated");
                    return ;
                }
                if (lhs.type.type != BCTypeEnum.Slice && lhs.type.type != BCTypeEnum.string8)
                {
                    bailout("lhs for concat has to be a slice not: " ~ enumToString(lhs.type.type));
                    return ;
                }
                auto lhsBaseType = _sharedCtfeState.elementType(lhs.type);
                if (_sharedCtfeState.size(lhsBaseType) > 4)
                {
                    bailout("for now only append to T[0].sizeof <= 4 is supported not : " ~ enumToString(lhsBaseType.type));
                    return ;
                }

                auto rhsBaseType = _sharedCtfeState.elementType(rhs.type);
                if(rhsBaseType != lhsBaseType)
                {
                     bailout("for now only concat between T[] and T[] is supported not: " ~ enumToString(lhs.type.type) ~" and " ~ enumToString(rhs.type.type) ~ e.toString);
                     return ;
                }

                if ((canWorkWithType(lhsBaseType) || lhsBaseType.type == BCTypeEnum.c8)
                        && basicTypeSize(lhsBaseType.type) == basicTypeSize(rhsBaseType.type))
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
                    bailout("We cannot cat " ~ _sharedCtfeState.typeToString(lhsBaseType) ~ " and " ~ _sharedCtfeState.typeToString(rhsBaseType));
                    return ;
                }
            }
            break;

        case TOK.add, TOK.min, TOK.mul, TOK.div, TOK.mod,
                TOK.and, TOK.or, TOK.xor, TOK.rightShift, TOK.leftShift:
            auto lhs = genExpr(e.e1, "BinExp lhs: " ~ enumToString(e.op));
            auto rhs = genExpr(e.e2, "BinExp rhs: " ~ enumToString(e.op));
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

            //TODO we should handle sign extension before bin-ops of coercing types
            if ((isFloat(lhs.type) && isFloat(rhs.type) && lhs.type.type == rhs.type.type) ||
                (canHandleBinExpTypes(retval.type.type, lhs.type.type) && canHandleBinExpTypes(retval.type.type, rhs.type.type)) ||
                (e.op == TOK.mod && canHandleBinExpTypes(rhs.type.type, retval.type.type)) ||
                ((e.op == TOK.equal || e.op == TOK.notEqual) && canHandleBinExpTypes(lhs.type.type, rhs.type.type)))
            {
                auto common_ty = commonTypeEnum(lhs.type.type, rhs.type.type);
                bool uns = (common_ty >= BCTypeEnum.u8 && common_ty <= BCTypeEnum.u64);
/+
                printf("common ty: commonTypeEnum(%s, %s) = %s\n",
                    enumToString(lhs.type.type).ptr,
                    enumToString(rhs.type.type).ptr,
                    enumToString(common_ty).ptr,
                );
                printf("e1.type: %s, e1.type: %s\n",
                    e.e1.type.toChars(),
                    e.e2.type.toChars(),
                );
                printf("op: %s\n",
                    enumToString(e.op).ptr
                );
+/
                const oldDiscardValue = discardValue;
                discardValue = false;
                /*debug (ctfe)
                        assert(!oldDiscardValue, "A lone BinExp discarding the value is strange");
                    */
                switch (cast(int) e.op)
                {
                case TOK.equal:
                    {
                        Eq3(retval, lhs, rhs);
                    }
                    break;

                case TOK.notEqual:
                    {
                        Neq3(retval, lhs, rhs);
                    }
                    break;
                case TOK.mod:
                    {
                        if (uns)
                        {
                            Umod3(retval, lhs, rhs);
                        }
                        else
                        {
                            Mod3(retval, lhs, rhs);
                        }
                    }
                    break;

                case TOK.add:
                    {
                        Add3(retval, lhs, rhs);
                    }
                    break;
                case TOK.min:
                    {
                        Sub3(retval, lhs, rhs);
                    }
                    break;
                case TOK.mul:
                    {
                        Mul3(retval, lhs, rhs);
                    }
                    break;
                case TOK.div:
                    {
                        if (uns)
                        {
                            Udiv3(retval, lhs, rhs);
                        }
                        else
                        {
                            Div3(retval, lhs, rhs);
                        }
                    }
                    break;

                case TOK.and:
                    {
                        And3(retval, lhs, rhs);
                    }
                    break;

                case TOK.or:
                    {
                        Or3(retval, lhs, rhs);
                    }
                    break;

                case TOK.xor:
                    {
                        Xor3(retval, lhs, rhs);
                    }
                    break;

                case TOK.rightShift:
                    {
                        auto maxShift = imm32(basicTypeSize(lhs.type.type) * 8 - 1);
                        if (rhs.vType != BCValueType.Immediate || rhs.imm32 > maxShift.imm32)
                        {
                            auto v = genTemporary(i32Type);
                            scope (exit) destroyTemporary(v);

                            Le3(v, rhs, maxShift);
                            Assert(v,
                                addError(e.loc,
                                "shift by %d is outside the range 0..%d", rhs, maxShift)
                            );
                        }
                        Rsh3(retval, lhs, rhs);
                    }
                    break;

                case TOK.leftShift:
                    {
                        auto maxShift = imm32(basicTypeSize(lhs.type.type) * 8 - 1);
                        if (rhs.vType != BCValueType.Immediate || rhs.imm32 > maxShift.imm32)
                        {
                            auto v = genTemporary(i32Type);
                            scope (exit) destroyTemporary(v);
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
                        bailout("Binary Expression " ~ enumToString(e.op) ~ " unsupported");
                        return ;
                    }
                }
                discardValue = oldDiscardValue;
            }

            else
            {
                bailout("Only binary operations on i32s are supported lhs.type: " ~ lhs.type.type.enumToString ~ " rhs.type: " ~ rhs.type.type.enumToString ~ " retval.type: " ~ enumToString(retval.type.type) ~  " -- " ~ e.toString);
                return ;
            }

            break;

        case TOK.orOr:
            {
                    const oldFixupTableCount = fixupTableCount;
                        {
                            Comment("|| before lhs");
                            auto lhs = genExpr(e.e1);
                            if (!lhs || (!canWorkWithType(lhs.type) && lhs.type.type != BCTypeEnum.Class))
                            {
                                bailout("could not gen lhs or could not handle its type " ~ e.toString);
                                return ;
                            }

                            fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(lhs,
                                    true));
                            Comment("|| after lhs");
                        }



                    {
                        Comment("|| before rhs");
                        auto rhs = genExpr(e.e2);

                        if (!rhs || (!canWorkWithType(rhs.type) && rhs.type.type != BCTypeEnum.Class))
                        {
                            bailout("could not gen rhs or could not handle its type " ~ e.toString);
                            return ;
                        }

                        fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(rhs,
                                true));
                        Comment("|| after rhs");
                        if (isBoolExp(e.e1) && !isBoolExp(e.e2))
                        {
                            Comment("fallout?");
                        }
                    }
            }
            break;

        case TOK.andAnd:
                {
                   // noRetval = true;
                   //     import std.stdio;
                   //     writefln("andandExp: %s -- e1.op: %s -- e2.op: %s", e.toString, e.e1.op.enumToString, e.e2.op.enumToString);
                    // If lhs is false jump to false
                    // If lhs is true keep going
                    const oldFixupTableCount = fixupTableCount;
                    {
                        auto lhs = genExpr(e.e1);
                        if (!lhs || (!canWorkWithType(lhs.type) && lhs.type.type != BCTypeEnum.Class))
                        {
                            bailout("could not gen lhs or could not handle its type " ~ e.toString);
                            return ;
                        }

                        fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(lhs,
                                false));

                        auto rhs = genExpr(e.e2);

                        if (!rhs || (!canWorkWithType(rhs.type) && rhs.type.type != BCTypeEnum.Class))
                        {
                            bailout("could not gen rhs or could not handle its type " ~ e.toString);
                            return ;
                        }

                        fixupTable[fixupTableCount++] = BoolExprFixupEntry(beginCndJmp(rhs,
                                false));
                    }

                break;
            }
        case TOK.comma:
            {
                genExpr(e.e1);
                retval = genExpr(e.e2);
            }
            break;
        default:
            {
                bailout("BinExp.Op " ~ enumToString(e.op) ~ " not handeled -- " ~ e.toString);
            }
        }

    }

    override void visit(TypeidExp e)
    {
        // dinterpret implements typeid as passthrough of sorts
        // so it may be alright to just ignore it
    }

    BCValue getAddressOf(VarDeclaration vd)
    {
        if (auto localVar = (cast(void*)vd) in vars)
        {
            assert(isStackValueOrParameter(*localVar));
            auto address = genTemporary(i32Type);
            printf("Loading Frame Ptr For: %s\n", vd.toChars());
            LoadFramePointer(address, localVar.stackAddr);
            Prt(address);
            return address;
        }
        assert(0, "cannot get address of " ~ vd.toString() ~ "for now");
    }


    override void visit(SymOffExp se)
    {
        lastLoc = se.loc;
        File(fromStringz(se.loc.filename));
        Line(se.loc.linnum);

        auto var = se.var;
        auto vd = se.var.isVarDeclaration();
        auto fd = se.var.isFuncDeclaration();
        if (vd)
        {
            auto v = getVariable(vd);

            if (v)
            {
                long index = -1;

                if (var.type.ty == Tarray || var.type.ty == Tsarray)
                {
                    const elemSize = var.type.nextOf().size();
                    index = elemSize ? se.offset / elemSize : -1;
                }

                if (isBasicBCType(v.type))
                {
                    // if we have a basic integral type here
                    // then we can just take the address of it at offset zero
                    // CAUTION this may be wrong in some cases
                    index = 0;
                }
                else
                {
                    //if (var.type.ty == Tclass || var.type.ty == Tstruct)
                    {
                        if (se.offset == 0)
                        {
                            // this is the same as a ref ...
                            // so we can return v itself ?
                            retval = v;
                            return ;
                        }

                        bailout("Cannot currently handle non-zero struct or class offsets"
                            ~ " - offset: " ~ itos(cast(int)se.offset) ~ " -- " ~ se.toString);
                    }
           /+         else
                    {
                        bailout("Cannot handle SymOffsetExp of type: " ~
                            enumToString(cast(TY)var.type.ty)
                        );
                    }
         +/           
                    return ;
                }

                if (index == -1)
                    bailout("could not compute index");


                // Everything in here is highly suspicious!
                // FIXME Design!
                // Things that are already heapValues
                // don't need to be stored ((or do they ??) ... do we need to copy) ?

                auto addr = genTemporary(i32Type);
                Alloc(addr, imm32(align4(_sharedCtfeState.size(v.type))));
                v.heapRef = BCHeapRef(addr);
                StoreToHeapRef(v);

                setVariable(vd, v);
                // register as pointer and set the variable to pointer as well;
                // since it has to be promoted to heap value now.
                retval = addr;
                retval.type = _sharedCtfeState.pointerOf(v.type);


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
                addUncompiledFunction(fd, &fnIdx);
            }
            bailout(!fnIdx, "Function could not be generated: -- " ~ fd.toString);

            assert(!inArgumentProcessing);
            auto fnPtr = genTemporary(i32Type);
            Alloc(fnPtr, imm32(4));
            Store32(fnPtr, imm32(fnIdx));
            retval = fnPtr;
            //retval.type.type = BCTypeEnum.Function; // ?
        }
        else
        {
            import dmd.asttypename;
            bailout(se.var.toString() ~ " is not a variable declaration but a " ~ astTypeName(se.var));
        }

    }

    override void visit(IndexExp ie)
    {
        lastLoc = ie.loc;

        File(fromStringz(ie.loc.filename));
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
        assert(!inArgumentProcessing);

        auto indexed = genExpr(ie.e1, "IndexExp.e1 e1[x]");

        if (!indexed)
        {
            bailout("could not create indexed variable from: " ~ ie.e1.toString ~ " -- !indexed: " ~ (!indexed ? "true" : "false") ~ " *  ignoreVoid: " ~ (ignoreVoid ? "true" : "false"));
            return ;
        }

        if (!indexed.type.type.anyOf([BCTypeEnum.string8, BCTypeEnum.Array, BCTypeEnum.Slice, BCTypeEnum.Ptr, BCTypeEnum.AArray]))
        {
            bailout("Unexpected IndexedType: " ~ enumToString(indexed.type.type) ~ " ie: " ~ ie
                .toString);
            return ;
        }

        bool isAA = (indexed.type.type == BCTypeEnum.AArray);
        
        if (isAA)
        {
        }

        auto length = getLength(indexed);

        currentIndexed = indexed;
        debug (ctfe)
        {
            import std.stdio;

            writeln("IndexedType", indexed.type.type.enumToString);
        }

        bool isString = (indexed.type.type == BCTypeEnum.string8);


        auto idx = genExpr(ie.e2).i32; // HACK
        BCValue ptr = genTemporary(i32Type);
        version (ctfe_noboundscheck)
        {
        }
        else
        {
            auto v = genTemporary(i32Type);
            Lt3(v, idx, length);
            scope(exit) destroyTemporary(v);
            Assert(v, addError(ie.loc,
                "ArrayIndex %d out of bounds %d", idx, length));
        }

        auto elemType = _sharedCtfeState.elementType(indexed.type);
        if (!elemType.type)
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
        auto offset = genTemporary(u32Type);
        scope(exit) destroyTemporary(offset);

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
                    bailout("the target type requires UTF-conversion: " ~ assignTo.type.type.enumToString);
                //TODO use UTF8 intrinsic!
            }

            //TODO assert that idx is not out of bounds;
            //auto inBounds = genTemporary(BCType(BCTypeEnum.i1));
            //auto arrayLength = genTemporary(BCType(BCTypeEnum.i32));
            //Load32(arrayLength, indexed.i32);
            //Lt3(inBounds,  idx, arrayLength);
            Assert(indexed.i32, addError(ie.loc, "we indexed a null array -- " ~ ie.toString));
            auto basePtr = getBase(indexed);
            scope(exit)
            {
                if (basePtr.vType != BCValueType.Immediate)
                    destroyTemporary(basePtr);
            }

            Mul3(offset, idx, imm32(elemSize));
            Add3(ptr, offset, basePtr);
            if (!retval || !ptr)
            {
                bailout("cannot gen: " ~ ie.toString);
                return ;
            }

            if (exprFlags & GenExprFlags.asAddress)
            {
                retval = ptr;
                return ;
            }

            retval.heapRef = BCHeapRef(ptr);

            if (isPassedByPointer(elemType.type))
            {
                // on structs we return the ptr!
                Set(retval.i32, ptr);
                retval.heapRef = BCHeapRef(ptr);
            }
            else if (isBasicBCType(elemType))
                LoadBasicType(retval.i32, ptr.i32, elemType.type);
            else
            {
                bailout("can only load basicTypes (i8, i16,i32 and i64, c8, c16, c32 and f23, f52) not: " ~ elemType.toString);
                return ;
            }

        }
    }

    void fixupBreak(uint oldBreakFixupCount, BCLabel breakHere)
    {
        foreach (jmp; breakFixups[oldBreakFixupCount .. breakFixupCount])
        {
            endJmp(jmp, breakHere);
        }
        breakFixupCount = oldBreakFixupCount;
    }

    void fixupContinue(uint oldContinueFixupCount, BCLabel continueHere)
    {
        //FIXME: I don't think we should have a global continueHere
        // which does not properly stack
        lastContinue = continueHere;
        foreach (jmp; continueFixups[oldContinueFixupCount .. continueFixupCount])
        {
            endJmp(jmp, continueHere);
        }
        continueFixupCount = oldContinueFixupCount;
    }

    BCBlock genBlock(Statement stmt, bool setCurrent = false,
        bool customBreakContinue = false)
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
        // it's unfortunate but we can be called with a null stmt :-/
        if (stmt !is null)
            stmt.accept(this);
        result.end = genLabel();

        // Now let's fixup thoose breaks and continues
        if (setCurrent)
        {
            switchFixup = oldSwitchFixup;
            if (!customBreakContinue)
            {
                fixupContinue(oldContinueFixupCount, result.begin);
                fixupBreak(oldBreakFixupCount, result.end);
            }
        }

        return result;
    }

    override void visit(ForStatement fs)
    {
        lastLoc = fs.loc;

        File(fromStringz(fs.loc.filename));
        Line(fs.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ForStatement %s", fs.toString);
        }

        BCValue initRetval;

        if (fs._init)
        {
            assert(0, "A forStatement should never have an initializer after semantic3?");
        }

        if (fs.condition !is null && fs._body !is null)
        {
            if (fs.condition.isBool(true))
            {
                infiniteLoop(fs._body, fs.increment);
                return ;
            }

            BCLabel condEval = genLabel();

            BCValue cond = genExpr(fs.condition, "ForStatement.condition");
            if (!cond)
            {
                bailout("Condition in for loop could not be generated");
                return ;
            }

            auto condJmp = beginCndJmp(cond.i32);
            const oldContinueFixupCount = continueFixupCount;
            const oldBreakFixupCount = breakFixupCount;
            auto _body = genBlock(fs._body, true, true);
            if (fs.increment)
            {
                fs.increment.accept(this);
            }
            fixupContinue(oldContinueFixupCount, _body.end);
            Jmp(condEval);
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
            Jmp(condEval);
            endCndJmp(condJmp, genLabel());
        }
        else
        { // fs.condition is null && fs._body !is null
            infiniteLoop(fs._body, fs.increment);
        }

    }

    override void visit(TryCatchStatement tc)
    {
/+
        PushCatch();
        pushCatches(tc.catches);
        genBlock(tc._body);
        PopCatch();
+/
        bailout("We currently can't handle ExecptionHandling");
    }

    override void visit(TryFinallyStatement tcf)
    {
        genBlock(tcf._body);
        auto _finally = genBlock(tcf.finalbody);
    }


    override void visit(ThrowStatement s)
    {
/+
        auto e = genExpr(s.exp);
        Store32(imm32(exceptionPointerAddr), e);
        Throw(e);
+/
        bailout("We currently can't handle ExecptionHandling");
    }

    void pushCatches(Catches* catches)
    {
        Comment("CatchBlock");
        typeof(beginCndJmp()) CJcastFailed;

        auto e_ptr = genTemporary(i32Type);
        scope (exit) destroyTemporary(e_ptr);
        Load32(e_ptr, imm32(exceptionPointerAddr));
        PrintString("Loading ExecptionPtr");
        auto castedValue = genTemporary(i32Type);
        scope (exit) destroyTemporary(castedValue);

        // this has to be done after vtbl pointers are known.
        // so we have to put this into a todo list.

        // @FIXME Don't assume we are only going to have 128 catches :)
        typeof(beginJmp())[128] break_catch_jmps;
        int n_break_catch_jmps = 0;
        foreach(i, _catch;*catches)
        {
            BCType catchType = toBCType(_catch.type);
            vars[cast(void*) _catch.var] = e_ptr;
            int castFnIdx = getDynamicCastIndex(catchType);
            if (!castFnIdx)
            {
                addDynamicCast(catchType, &castFnIdx);
            }
            Comment("Calling catch");
            Call(castedValue.i32, imm32(castFnIdx), [e_ptr]);
            PrintString("Catch [" ~ itos(cast(int)i) ~ "] :" ~ _catch.handler.toString);
            Comment("CJcastFailed");
            CJcastFailed = beginCndJmp(castedValue, false);
            {
                genBlock(_catch.handler);
                break_catch_jmps[n_break_catch_jmps++] = beginJmp();
            }
            endCndJmp(CJcastFailed, genLabel());
        }
        auto Lbreak =  genLabel();
        foreach(j;break_catch_jmps[0 .. n_break_catch_jmps])
        {
            endJmp(j, Lbreak);
        }
    }

    override void visit(Expression e)
    {
        lastLoc = e.loc;

        File(fromStringz(e.loc.filename));
        Line(e.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("Expression %s", e.toString);

        }
        import dmd.asttypename;
        bailout("Cannot handle Expression: " ~ e.astTypeName ~  " :: " ~ e.toString);
    }

    override void visit (DelegateExp de)
    {
        auto dgType = toBCType(de.type);
        auto dg = genTemporary(dgType);
        
        if (!dg) { bailout("Could not generate DelegateExp"); return ; }

        Alloc(dg.i32, imm32(DelegateDescriptor.Size), dgType);
        Comment("Store FunctionPtr");

        IndexedScaledStore32(dg.i32,
            imm32(_sharedCtfeState.getFunctionIndex(de.func)),
            imm32(DelegateDescriptor.FuncPtrOffset / 4),
            4
        );

        Comment("Store ContextPtr");

        BCValue context;
        auto contextType = toBCType(de.e1.type);
        // printf("ContextType: %s\n", de.e1.type.toPrettyChars(true)); //DEBUGLINE

        if (contextType.type == BCTypeEnum.Function)
        {
            context = closureChain;
        }
        else
        {
            context = _this;
        }

        // at this point we may not have a context for the delegate,
        // seems to be happing in something having to do with the type-info

        if (context)
        {
            IndexedScaledStore32(dg.i32,
                context.i32,
                imm32(DelegateDescriptor.ContextPtrOffset / 4),
                4
            );
        }
        retval = dg;
    }

    override void visit(NullExp ne)
    {
        lastLoc = ne.loc;

        File(fromStringz(ne.loc.filename));
        Line(ne.loc.linnum);
        retval = BCValue.init;
        retval.vType = BCValueType.Immediate;
        retval.type.type = BCTypeEnum.Null;
    }

    override void visit(HaltExp he)
    {
        lastLoc = he.loc;

        File(fromStringz(he.loc.filename));
        Line(he.loc.linnum);
        retval = BCValue.init;
        Assert(imm32(0), addError(he.loc, "HaltExp"));
    }

    override void visit(DotIdExp de)
    {
        printf("Encountering DotIdExp %s ... this means sema has not been run\n", de.toChars);
        assert(0);
    }

    override void visit(SliceExp se)
    {
        lastLoc = se.loc;

        File(fromStringz(se.loc.filename));
        Line(se.loc.linnum);
        debug (ctfe)
        {
            import core.stdc.stdio;

            printf("SliceExp %s\n", se.toChars());
            printf("se.e1 %s\n", se.e1.toChars());
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

            if (inArgumentProcessing)
            {
               bailout("currently we cannot slice during argument processing");
               return ;
            }

            auto origSlice = genExpr(se.e1, "SliceExp origSlice");
            if (origSlice && origSlice.type.type != BCTypeEnum.Slice && origSlice.type.type != BCTypeEnum.string8)
            {
                bailout(!origSlice.type.type.anyOf([BCTypeEnum.Array, BCTypeEnum.Ptr]),
                    "SliceExp: Slice Ptr or Array expected but got: " ~
                     origSlice.type.type.enumToString
                );
                origSlice.type = _sharedCtfeState.sliceOf(_sharedCtfeState.elementType(origSlice.type));
            }

            bailout(!origSlice, "could not get slice expr in " ~ se.toString);

            currentIndexed = origSlice;
            auto elemType = _sharedCtfeState.elementType(origSlice.type);
            if (!elemType.type)
            {
                bailout("could not get elementType for: " ~ _sharedCtfeState.typeToString(origSlice.type) ~ " -- " ~ se.toString);
                return ;
            }
            auto elemSize = _sharedCtfeState.size(elemType);

            auto newSlice = genTemporary(origSlice.type);
            Alloc(newSlice.u32, imm32(SliceDescriptor.Size), origSlice.type);

            auto origLength = getLength(origSlice);
            if (!origLength)
            {
                bailout("could not gen origLength in " ~ se.toString);
                return ;
            }
            BCValue newLength = genTemporary(i32Type);
            scope(exit) destroyTemporary(newLength);

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

            // this asserts that lwr <= upr
            {
                Ge3(BCValue.init, lwr.u32, upr.u32);
                auto CJoob = beginCndJmp();
                {
                    Assert(imm32(0), addError(se.loc, "slice [%llu .. %llu] is out of bounds", lwr, upr));
                }
                endCndJmp(CJoob, genLabel());
            }
            Sub3(newLength, upr.u32, lwr.u32);

            setLength(newSlice, newLength);

            auto origBase = getBase(origSlice);
            if (!origBase)
            {
                bailout("could not gen origBase in " ~ se.toString);
                return ;
            }

            BCValue newBase = genTemporary(i32Type);
            scope(exit) destroyTemporary(newBase);
            Mul3(newBase, lwr.i32, imm32(elemSize));
            Add3(newBase, newBase, origBase);

            setBase(newSlice.i32, newBase.i32);

            retval = newSlice;
        }
    }

    override void visit(DotVarExp dve)
    {
        lastLoc = dve.loc;
        File(fromStringz(dve.loc.filename));
        Line(dve.loc.linnum);

        const bcType = toBCType(dve.e1.type);
        if (dve.e1.type.ty == Tstruct && (cast(TypeStruct) dve.e1.type).sym)
        {
            auto structDeclPtr = (cast(TypeStruct) dve.e1.type).sym;
            auto structTypeIndex = _sharedCtfeState.getStructIndex(structDeclPtr);
            if (structTypeIndex)
            {
                BCStruct _struct = _sharedCtfeState.structTypes[structTypeIndex - 1];

                auto vd = dve.var.isVarDeclaration;
                assert(vd);

                const fInfo = getFieldInfo(bcType, vd);
                const fIndex = fInfo.index;
                if (fIndex == -1)
                {
                    bailout("Field cannot be found " ~ dve.toString);
                    return ;
                }
/+
                if  (_struct.voidInit[fIndex])
                {
                    bailout("We don't handle struct fields that may be void");
                    return ;
                }
+/
                int offset = fInfo.offset;
                if (offset == -1)
                {
                    bailout("Could not get field-offset of: " ~ vd.toString);
                    return ;
                }
                BCType varType = fInfo.type;
                if (!varType.type)
                {
                    bailout("struct member " ~ itos(fIndex) ~ " has an empty type... This must not happen! -- " ~ dve.toString);
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
                Comment("We should now have lhs");
                if (lhs.type.type != BCTypeEnum.Struct)
                {
                    bailout(
                        "lhs.type != Struct but: " ~ enumToString(lhs.type.type) ~ " " ~ dve
                        .toString);
                }

                if (!(isStackValueOrParameter(lhs) || lhs.vType == BCValueType.Temporary))
                {
                    bailout("Unexpected lhs-type: " ~ enumToString(lhs.vType));
                    return ;
                }

                getField(lhs, fInfo, &retval);

                debug (ctfe)
                {
                    import std.stdio;

                    writeln("dve.var : ", dve.var.toString);
                    writeln(dve.var.isVarDeclaration.offset);
                }
            }
        }
        else if (dve.e1.type.ty == Tclass && (cast(TypeClass) dve.e1.type).sym)
        {
            const c = _sharedCtfeState.classTypes[bcType.typeIndex - 1];
            const fInfo = getFieldInfo(bcType, cast(VarDeclaration)dve.var);
            const offset = fInfo.offset;

            if (offset == -1)
            {
                bailout("we failed to get the field -- " ~ dve.toString);
                return ;
            }

            BCType varType = fInfo.type;
            if (!varType.type)
            {
                bailout("class field has an empty type... This must not happen! -- " ~ dve.toString);
                return ;
            }

            retval = (assignTo && assignTo.vType == BCValueType.StackValue) ? assignTo : genTemporary(
                toBCType(dve.type));

            auto lhs = genExpr(dve.e1, "DotVarExp: dve.e1");

            if (!(isStackValueOrParameter(lhs) || lhs.vType == BCValueType.Temporary))
            {
                bailout("Unexpected lhs.vType: " ~ enumToString(lhs.vType) ~ " lhs.type: " ~ _sharedCtfeState.typeToString(lhs.type));
                return ;
            }

            getField(lhs, fInfo, &retval);

            //bailout("Class.field still has to be implemented fi:" ~ itos(fieldIndex) ~ " lvl:" ~ itos(level));
        }
        else
        {
            bailout("Can only take members of a struct/class for now");
        }

    }

    void getField(BCValue lhs, FieldInfo fInfo, BCValue* retvalp)
    {
        // import std.stdio;
        // writeln("lhs: ", lhs, " FieldInfo: ", fInfo, "retvalP:", retvalp);
        auto ptr = genTemporary(fInfo.type);
        // this temporary survives as a heapRef DO NOT DESTORY

        Add3(ptr.i32, lhs.i32, imm32(fInfo.offset));
        auto rv = *retvalp;

        if (isPassedByPointer(ptr.type.type))
        {
            Comment("getField");
            Set(rv.i32, ptr);
        }
        else if (_sharedCtfeState.size(ptr.type) == 8)
        {
            Comment(_sharedCtfeState.typeToString(ptr.type));
            Load64(rv.i32, ptr);
        }
        else
            Load32(rv.i32, ptr);
        if (!ptr)
        {
            bailout("could not access field: " ~ itos(fInfo.index));
            return ;
        }
        (*retvalp).heapRef = BCHeapRef(ptr);
    }

    override void visit(CommaExp ce)
    {
        retval = genExpr(ce.e2);
    }

    private bool constAle(ArrayLiteralExp ale)
    {
        bool isConst = true;

        if (!ale)
            isConst = false;

        if (isConst) foreach(e;*ale.elements)
        {
            if (!e.isConst() && !e.isStringExp() && !constAle(e.isArrayLiteralExp()))
            {
                isConst = false;
                break;
            }
        }

        return isConst;
    }

    override void visit(ArrayLiteralExp ale)
    {
        lastLoc = ale.loc;

        File(fromStringz(ale.loc.filename));
        Line(ale.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ArrayLiteralExp %s insideArrayLiteralExp %d",
                ale.toString, insideArrayLiteralExp);
        }

        auto elemType = toBCType(ale.type.nextOf);

        if (elemType.type != BCTypeEnum.Void && (!elemType.type || !_sharedCtfeState.size(elemType)))
        {
            bailout("elemType type is invalid or has invalid size -- " ~ ale.toString ~ "elemType.type: " ~ enumToString(elemType.type));
            return ;
        }

        auto arrayLength = cast(uint) ale.elements.dim;
        //_sharedCtfeState.getArrayIndex(ale.type);
        auto arrayType = BCArray(elemType, arrayLength);
        debug (ctfe)
        {
            writeln("Adding array of Type:  ", arrayType);
        }

       
        if (constAle(ale))
        {
            retval = genArg(ale);
            return ;
        }
        auto oldAssignTo = assignTo;
        scope(exit) assignTo = oldAssignTo;
        if (assignTo)
        {
            retval = assignTo;
        }
        else
        {
            retval = genTemporary(toBCType(ale.type));
        }

        // not a constant array literal so now need to generate the expression at runtime
        // first we allocate the memory.
        //[[1,2],[3, 4], [a,b] ,[d, e]];
        auto elemSize = _sharedCtfeState.size(elemType, true);
        auto size = SliceDescriptor.Size + (arrayLength * elemSize);
        auto elemDest = genTemporary(i32Type);
        scope (exit) destroyTemporary(elemDest);

        Alloc(retval, imm32(size));
        setLength(retval, imm32(arrayLength));
        Add3(elemDest, retval, imm32(SliceDescriptor.Size));
        setBase(retval, elemDest);

        // we need to keep track of the current offset in the array literal
        // array literals can be nested in other array literals or structs
        // which is why need to keep an offset stack.
        baseOffsets[baseOffsetCount++] = elemDest;
        scope(exit) baseOffsetCount--;
        // now we can start generating the elements
        BCValue defaultElem;
        if (ale.basis)
        {
            defaultElem = genExpr(ale.basis);
        }
        // now default value is set if we have one
        foreach(elem;*ale.elements)
        {
            assignTo = elemDest;
            if (elem)
            {
                auto elemValue = genExpr(elem);
                SetMem(elemDest, elemValue);
            }
            else
            {
                assert(defaultElem);
                SetMem(elemDest, defaultElem);
            }
            Add3(elemDest, elemDest, imm32(elemSize));
        }
    }

    BCValue AllocSlice(BCValue sliceDescAddr, BCValue desired_length, BCType slice_type)
    {
        if (slice_type.type == BCTypeEnum.Slice)
        {
            BCSlice slice = _sharedCtfeState.sliceTypes[slice_type.typeIndex - 1];
            auto elType = slice.elementType;
            auto elSize = _sharedCtfeState.size(elType, true);

            auto allocSize = genTemporary(i32Type);
            auto newMem = genTemporary(i32Type);
            scope(exit) destroyTemporary(newMem);

            Mul3(allocSize, desired_length, imm32(elSize));
            Alloc(newMem, allocSize, slice_type);
            setLength(sliceDescAddr, desired_length);
            setBase(sliceDescAddr, newMem);
            
            return allocSize;
        }
        else
            assert(0, "Alloc Slice is only supposed to be called on slices");
    }

    import dmd.ctfeexpr : ClassReferenceExp;
    override void visit(ClassReferenceExp cre)
    {
        lastLoc = cre.loc;

        auto cIdx = _sharedCtfeState.getClassIndex(cre.originalClass());
        assert(cIdx);
        BCClass _class = _sharedCtfeState.classTypes[cIdx - 1];
        auto ct = _sharedCtfeState.classDeclTypePointers[cIdx - 1];
        BCType cType = BCType(BCTypeEnum.Class, cIdx);

        auto size = align4(_class.size);
        BCValue val;

        if (assignTo)
        {
            val = assignTo;
            assignTo = BCValue.init;
        }
        else
        {
            val = genTemporary(cType);
        }
        Alloc(val.i32, imm32(size), cType);

        uint offset = ClassMetaData.Size;
        Store32AtOffset(val.i32, imm32(cIdx), ClassMetaData.TypeIdIdxOffset);

        BCValue fieldAddr = genTemporary(i32Type);

        foreach (i, elem; *cre.value.elements)
        {
            BCType field_type = toBCType(ct.fields[i].type);
            Comment("StructLiteralExp element: " ~ elem.toString);
            if (!elem)
            {
                bailout("NullElement encountered in: " ~ cre.toString);
                return ;
            }
            auto elexpr = genExpr(elem, "ClassReferenceExp element");
            immutable elemSize = _sharedCtfeState.size(elexpr.type, true);

            if (!elexpr)
            {
                bailout("could not gen ClassLiteralElem: " ~ elem.toString);
                return ;
            }

            pushLiteralElem(val, fieldAddr, field_type, offset, elexpr, elemSize);

            offset += align4(elemSize);
        }

        retval = val;
    }

    override void visit(StructLiteralExp sle)
    {
        lastLoc = sle.loc;

        File(fromStringz(sle.loc.filename));
        Line(sle.loc.linnum);

        debug (ctfe)
        {
            import core.stdc.stdio;

            printf("StructLiteralExp %s insideArrayLiteralExp %d\n",
                sle.toChars(), insideArrayLiteralExp);
        }

        auto sd = sle.sd;

        auto idx = _sharedCtfeState.getStructIndex(sd);
        if (!idx)
        {
            bailout("structType could not be found: " ~ sd.toString);
            return ;
        }
        BCStruct _struct = _sharedCtfeState.structTypes[idx - 1];
        auto st = _sharedCtfeState.structDeclTypePointers[idx - 1];

        foreach (i; 0 .. _struct.memberCount)
        {
            if (_struct.voidInit[i])
            {
                bailout("We don't handle structs with void initializers ... right now");
                return ;
            }

            auto ty = _struct.memberTypes[i];
            if (!ty.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.string8, BCTypeEnum.Slice, BCTypeEnum.Array,
                BCTypeEnum.i8, BCTypeEnum.u16, BCTypeEnum.i32, BCTypeEnum.i64, BCTypeEnum.f23, BCTypeEnum.f52,
                BCTypeEnum.u8, BCTypeEnum.u16, BCTypeEnum.u32, BCTypeEnum.u64,
                BCTypeEnum.c8, BCTypeEnum.c16, BCTypeEnum.c32, BCTypeEnum.Function, BCTypeEnum.Class]))
            {
                bailout( "can only deal with ints and uints atm. not: (" ~ enumToString(ty.type) ~ ", " ~ itos(
                        ty.typeIndex) ~ ")");
                return ;
            }
        }

        auto struct_size = align4(_struct.size);

        BCValue structVal;
        if (!struct_size)
        {
            bailout("invalid struct size! (someone really messed up here!!)");
            return ;
        }

        structVal = assignTo ? assignTo : genTemporary(BCType(BCTypeEnum.Struct, idx));
        Alloc(structVal.i32, imm32(struct_size), BCType(BCTypeEnum.Struct, idx));
        
        structVal.type = BCType(BCTypeEnum.Struct, idx);

        initStruct(structVal);

        uint offset = 0;

        BCValue fieldAddr = genTemporary(i32Type);
        scope(exit) destroyTemporary(fieldAddr);

        foreach (i, elem; *sle.elements)
        {
            BCType field_type = toBCType(st.fields[i].type);
            Comment("StructLiteralExp element: " ~ elem.toString);
            if (!elem)
            {
                bailout("NullElement encountered in: " ~ sle.toString);
                return ;
            }
            auto elexpr = genExpr(elem, "StructLiteralExp element");
            immutable elemSize = _sharedCtfeState.size(elexpr.type, true);

            debug (ctfe)
            {
                import std.stdio;
                writeln("elExpr: ", elexpr.toString, " elem ", elem.toString);
            }

            if (!elexpr)
            {
                bailout("could not gen StructLiteralElement: " ~ elem.toString);
                return ;
            }

            pushLiteralElem(structVal, fieldAddr, field_type, offset, elexpr, elemSize);

            offset += align4(elemSize);
        }

        retval = structVal;
    }

    bool pushLiteralElem(BCValue agg, BCValue fieldAddr, BCType field_type, uint offset, BCValue elexpr, const uint elemSize)
    {
        if (!inArgumentProcessing)
        {
            if (offset)
                Add3(fieldAddr, agg.i32, imm32(offset));
            else
                Set(fieldAddr, agg.i32);

            if (field_type.type == BCTypeEnum.Array)
            {
                BCArray _array = _sharedCtfeState.arrayTypes[field_type.typeIndex - 1];

                if (_array.elementType == elexpr.type)
                {
                    auto base = getBase(fieldAddr);
                    ArrayBroadcast(base, imm32(_array.length), field_type, elexpr);
                }
                else
                {
                    auto memSize = _sharedCtfeState.size(_array.elementType, true);
                    MemCpy(getBase(fieldAddr), getBase(elexpr), imm32(memSize));
                }
            }
            else if (field_type.type == BCTypeEnum.Slice)
            {
                BCSlice _slice = _sharedCtfeState.sliceTypes[field_type.typeIndex - 1];

                auto length = getLength(elexpr);
                //AllocSlice(fieldAddr, length, field_type);

                if (_slice.elementType == elexpr.type)
                {
                    assert(0, "Not sure that an structLiteralExp can contain a boardcast assignment");
                    //ArrayBroadcast(getBase(fieldAddr), length, field_type);
                }
                else
                {
                    auto memSize = AllocSlice(fieldAddr, length, field_type);
                    auto destBase = getBase(fieldAddr);
                    auto srcBase = getBase(elexpr);
                    scope(exit)
                    {
                        if (destBase.vType != BCValueType.Immediate)
                            destroyTemporary(destBase);
                        if (srcBase.vType != BCValueType.Immediate)
                            destroyTemporary(srcBase);
                    }
                    MemCpy(getBase(fieldAddr), getBase(elexpr), memSize);
                    destroyTemporary(memSize);
                }
            }
            else SetMem(fieldAddr, elexpr);
        }
        else
        {
            assert(0, "We musn't get here when processing arguments");
        }

        return true;
    }

    override void visit(DollarExp de)
    {
        lastLoc = de.loc;

        File(fromStringz(de.loc.filename));
        Line(de.loc.linnum);
        if (currentIndexed.type.type == BCTypeEnum.Array
            || currentIndexed.type.type == BCTypeEnum.Slice
            || currentIndexed.type.type == BCTypeEnum.string8)
        {
            retval = getLength(currentIndexed);
            assert(retval);
        }
        else
        {
            bailout("We could not find an indexed variable for " ~ de.toString);
            return ;
        }
    }

    void LoadBasicType(BCValue value, BCValue addr, BCTypeEnum type)
    {
        const size = basicTypeSize(type);
        switch (size)
        {
            case 1 : Load8(value, addr); break;
            case 2 : Load16(value, addr); break;
            case 4 : Load32(value, addr); break;
            case 8 : Load64(value, addr); break;
            default: assert(0, "Unsupported size");
        }
    }

    void StoreBasicType(BCValue addr, BCValue value, BCTypeEnum type, int line = __LINE__)
    {
        Comment("StoreBasicType From: " ~ itos(line));
        const size = basicTypeSize(type);
        switch (size)
        {
            case 1 : Store8(addr, value); break;
            case 2 : Store16(addr, value); break;
            case 4 : Store32(addr, value); break;
            case 8 : Store64(addr, value); break;
            default: assert(0, "Unsupported size");
        }
    }



    override void visit(AddrExp ae)
    {
        lastLoc = ae.loc;

        File(fromStringz(ae.loc.filename));
        Line(ae.loc.linnum);
        //bailout("We don't handle AddrExp");
        auto e1 = genExpr(ae.e1, GenExprFlags.asAddress, "AddrExp");

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
        lastLoc = te.loc;

        File(fromStringz(te.loc.filename));
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
        lastLoc = ce.loc;

        File(fromStringz(ce.loc.filename));
        Line(ce.loc.linnum);
        Not(retval, genExpr(ce.e1));
    }

    override void visit(PtrExp pe)
    {
        lastLoc = pe.loc;

        File(fromStringz(pe.loc.filename));
        Line(pe.loc.linnum);
        bool isFunctionPtr = pe.type.ty == Tfunction;
        auto addr = genExpr(pe.e1);

        auto baseType = isFunctionPtr ? i32Type : _sharedCtfeState.elementType(addr.type);

        debug(ctfe)
        {

            import std.stdio;

            writeln("PtrExp: ", pe.toString, " = ", addr);
            writeln("addr.type: ", addr.type);
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

        auto bts = basicTypeSize(baseType.type);

        if (bts)
        {
            LoadBasicType(retval, addr, baseType.type);
        }
        else if (baseType.type == BCTypeEnum.Ptr)
        {
            assert(0, "Don't support multiple levels of indirection yet");
        }
        else if (baseType.type == BCTypeEnum.Struct)
        {

            const size = _sharedCtfeState.size(baseType);
            if (size)
            {
                Alloc(retval.i32, imm32(size));
                MemCpy(retval.i32, addr.i32, imm32(size));
            }

            Set(retval.i32, addr.i32);
        }
        else
        {
           bailout("Only 4 byte or 8 byte basic type are supported not " ~ itos(bts)
                ~ "on  "~ _sharedCtfeState.typeToString(baseType) ~ " for -- " ~ pe.toString);
            return ;
        }

        // FIXME when we are ready to support more than i32Ptr the direct calling of load
        // has to be replaced by a genLoadForType() function that'll convert from
        // heap+representation to stack+representation.

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
        lastLoc = ne.loc;
        debug (ctfe)
        {
            import std.stdio;
            printf("NewExp: %s\n", ne.toChars());
        }
        File(fromStringz(ne.loc.filename));
        Line(ne.loc.linnum);
        auto type = toBCType(ne.newtype);
        uint typeSize;
        BCValue ptr = (assignTo ? assignTo : genTemporary(type));
        if (assignTo) assignTo = BCValue.init;

        if (type.type == BCTypeEnum.Slice || type.type == BCTypeEnum.string8)
        {
            assert(ne.arguments.dim  == 1 || ne.arguments.dim == 0,
                "new Slice is only expected to have one or zero arguments");

            const hasLength = (ne.arguments.dim == 1);

            const elemSize =
                _sharedCtfeState.size(_sharedCtfeState.elementType(type), true);

            if (!elemSize)
            {
                bailout("We can't compute a size for the Slice-ElementType in -- "
                    ~ ne.toString);
                return ;
            }

            BCValue size;
            {
                size = genTemporary(u32Type);
                scope(exit) destroyTemporary(size);
                const length = hasLength ? genExpr((*ne.arguments)[0]).u32 : imm32(1);

                Set(size, length);
                Mul3(size, size, imm32(elemSize));
                Add3(size, size, imm32(SliceDescriptor.Size));
                Alloc(ptr, size, type);

                setLength(ptr.u32, length);
                auto base = genTemporary(i32Type);
                scope(exit) destroyTemporary(base);
                Add3(base, ptr, imm32(SliceDescriptor.Size));
                setBase(ptr, base);
                retval = ptr;
                return ;
            }

        }
        else
        {
            typeSize = _sharedCtfeState.size(type);
            ptr = ptr.i32;
        }

        if (!typeSize)
            bailout(type.toString ~ "does not seem to have a size in: " ~ ne.toString);
        else
            Alloc(ptr, imm32(typeSize), type);

        if (isBasicBCType(type) && typeSize <= 4)
        {
            auto value = ne.arguments && ne.arguments.dim == 1 ? genExpr((*ne.arguments)[0]) : imm32(0);
            Store32(ptr, value.i32);
        }
        else if (type.type == BCTypeEnum.Class)
        {
            auto ctor = ne.member;

            int cIdx;

            cIdx = lookupConstructor(ctor, type);
            // printf("Ctor: %s\n", ctor ? ctor.fbody.toChars() : "default class initializer"); //debugline
            if (!cIdx)
            {
                // in the case where ctor is null we are doing a default constructor.
                // in order to do that properly we need to do the one for our parents first
                if (!ctor)
                {
                    auto pIndex = _sharedCtfeState.classTypes[type.typeIndex - 1].parentIdx;
                    while (pIndex)
                    {
                        auto pType = BCType(BCTypeEnum.Class, pIndex);
                        auto pCtorIdx = lookupConstructor(null, pType);
                        if (pCtorIdx)
                        {
                            // in case there is a default ctor no need to walk up anymore
                            break;
                        }
                        addUncompiledConstructor(null, pType, &pCtorIdx);
                        pIndex = _sharedCtfeState.classTypes[pIndex - 1].parentIdx;
                    }

                }

                addUncompiledConstructor(ctor, type, &cIdx);
            }

            BCValue[] cTorArgs;
            cTorArgs.length = ne.arguments.dim + 1;
            foreach(idx; 0 .. ne.arguments.dim)
            {
                cTorArgs[idx] = genExpr((*ne.arguments)[idx]);
            }
            // ptr  = this; which should already point
            // to freshly allocated memory.
            cTorArgs[ne.arguments.dim] = ptr.u32;

            Comment("ConstructorCall");
            Call(ptr, imm32(cIdx), cTorArgs);
            ptr.type = type;
        }
        else
        {
            bailout("Can only new basic Types under <=4 bytes for now -- typeSize: " ~ typeSize.itos);
        }

        // TODO do proper handling of the arguments to the newExp.
        retval = ptr;

        return ;

    }

    override void visit(ArrayLengthExp ale)
    {
        lastLoc = ale.loc;

        File(fromStringz(ale.loc.filename));
        Line(ale.loc.linnum);
        auto array = genExpr(ale.e1);
        auto arrayType = array.type.type;
        if (arrayType == BCTypeEnum.string8 || arrayType == BCTypeEnum.Slice || arrayType == BCTypeEnum.Array)
        {
            retval = getLength(array);
        }
        else
        {
            bailout("We only handle Slice, Array, and String-Length for now atm. given : " ~ enumToString(array.type.type) ~ " :: " ~ ale.e1.toString);
        }
    }

    void setLength(BCValue arr, BCValue newLength)
    {
        debug(nullPtrCheck)
        {
            Comment("SetLengthNullPtrCheck");
            Assert(arr.i32, addError(lastLoc, "setLength: arrPtr must not be null"));
        }
        Store32AtOffset(arr.i32, newLength.i32, SliceDescriptor.LengthOffset);
    }

    BCValue getCapacity(BCValue arr)
    {
        BCValue capacity;

        debug(nullPtrCheck)
        {
            Assert(arr.i32, addError(lastLoc, "getCapacity: arrPtr must not be null"));
        }
        if (arr.type.type == BCTypeEnum.Slice || arr.type.type == BCTypeEnum.string8)
        {
            capacity = genTemporary(i32Type);
            Load32FromOffset(capacity, arr.i32, SliceDescriptor.CapacityOffset);

        }
        else
        {
            bailout("Trying to get capacity from something which is not a slice");
        }

        return capacity;
    }

    void setCapacity(BCValue arr, BCValue newCapa)
    {
        if (arr.type.type == BCTypeEnum.Slice || arr.type.type == BCTypeEnum.string8)
        {
            Store32AtOffset(arr.i32, newCapa.i32, SliceDescriptor.CapacityOffset);
        }
        else
        {
            bailout("Trying to set capacity on something which is not a slice");
        }
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
                    bailout("arrayIndex: " ~ itos(idx) ~ " is out of bounds");
                    return BCValue.init;
                }
                length = imm32(_sharedCtfeState.arrayTypes[idx - 1].length);
            }
            else
            {
                length = genTemporary(i32Type);
                BCValue lengthPtr;
                // if (arr is null) skip loading the length
                auto CJskipLoad = beginCndJmp(arr.u32, /*"skipLoad"*/);
                Load32FromOffset(length, arr.u32, SliceDescriptor.LengthOffset);
                auto LAfterLoad = genLabel(/*afterLoad*/);
                endCndJmp(CJskipLoad, LAfterLoad);
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
        Assert(arr.u32, addError(lastLoc, "cannot set setBase of null array"));
        Store32AtOffset(arr.u32, newBase, SliceDescriptor.BaseOffset);
    }

    BCValue getBase(BCValue arr)
    {
        if (arr)
        {
            Assert(arr.i32, addError(lastLoc, "cannot getBase from null array " ~ itos(uniqueCounter++)));
            BCValue baseAddr;
            if (inArgumentProcessing)
            {
                assert(0, "we must not get here when procesing arguments");
            }

            {
                baseAddr = genTemporary(i32Type);

                BCValue baseAddrPtr;
                if (SliceDescriptor.BaseOffset)
                {
                    baseAddrPtr = genTemporary(u32Type);
                    Add3(baseAddrPtr, arr.i32, imm32(SliceDescriptor.BaseOffset));
                }
                else
                {
                    baseAddrPtr = arr.i32;
                }
                Load32(baseAddr, baseAddrPtr);
                if (SliceDescriptor.BaseOffset) destroyTemporary(baseAddrPtr);
            }
            return baseAddr;
        }
        else
        {
            bailout("cannot get baseAddr without a valid arr");
            return BCValue.init;
        }
    }


    int bitfieldOffset(BCStruct* structType) pure const
    {
        return align4(structType.size) + StructMetaData.VoidInitBitfieldOffset;
    }

    /// Params:
    ///     fIndex = fieldIndex of the field to be set to void/nonVoid
    ///     nonVoid = true if seting to nonVoid false if setting to Void
    void setMemberVoidInit(BCValue structPtr, int fIndex, bool nonVoid)
    {
        assert(structPtr.type.type == BCTypeEnum.Struct, "setMemberVoidInit may only be called on structs for now");
        assert(structPtr.type.typeIndex, "StructPtr typeIndex invalid");
        auto structType = &_sharedCtfeState.structTypes[structPtr.type.typeIndex - 1];

        auto bitfieldIndex = structType.voidInitBitfieldIndex(fIndex);

        BCValue bitFieldAddr  = genTemporary(i32Type);
        scope(exit) destroyTemporary(bitFieldAddr);
        BCValue bitFieldValue = genTemporary(i32Type);
        scope(exit) destroyTemporary(bitFieldValue);

        Add3(bitFieldAddr, structPtr.i32, imm32(bitfieldOffset(structType)));
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
        auto structType = &_sharedCtfeState.structTypes[structPtr.type.typeIndex - 1];

        auto bitfieldIndex = structType.voidInitBitfieldIndex(fIndex);

        BCValue bitFieldAddr  = genTemporary(i32Type);
        scope(exit) destroyTemporary(bitFieldAddr);

        BCValue bitFieldValue = genTemporary(i32Type);
        Add3(bitFieldAddr, structPtr.u32, imm32(bitfieldOffset(structType)));
        Load32(bitFieldValue, bitFieldAddr);

        And3(bitFieldValue, bitFieldValue, imm32(1 << bitfieldIndex));
        return bitFieldValue;
    }


    void LoadFromHeapRef(BCValue hrv, uint line = __LINE__)
    {
        // import std.stdio; writeln("Calling LoadHeapRef from: ", line); //DEBUGLINE
        if(hrv.type.type.anyOf([BCTypeEnum.i64, BCTypeEnum.u64, BCTypeEnum.f52, BCTypeEnum.i32, BCTypeEnum.i16, BCTypeEnum.i8, BCTypeEnum.u32, BCTypeEnum.u16, BCTypeEnum.u8, BCTypeEnum.c8, BCTypeEnum.c16, BCTypeEnum.c32, BCTypeEnum.f23]))
            LoadBasicType(hrv.i32, BCValue(hrv.heapRef), hrv.type.type);
        // since the stuff below are heapValues we may not want to do this ??
        else if (hrv.type.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.Slice, BCTypeEnum.Array, BCTypeEnum.string8]))
            MemCpy(hrv.u32, BCValue(hrv.heapRef).u32, imm32(_sharedCtfeState.size(hrv.type)));
        else
            bailout(enumToString(hrv.type.type) ~ " is not supported in LoadFromHeapRef");

    }

    void StoreToHeapRef(BCValue hrv, uint line = __LINE__)
    {
        Comment("Store to Heapref from:" ~ itos(line));
        auto heapRef = BCValue(hrv.heapRef);
        //auto heapRef = genTemporary(_sharedCtfeState.pointerOf(hrv.type));
        //Set(heapRef.i32, BCValue(hrv.heapRef).i32);

        if(hrv.type.type.anyOf([BCTypeEnum.i64, BCTypeEnum.u64, BCTypeEnum.f52]))
            Store64(heapRef.u32, hrv);
        else if (hrv.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.i16, BCTypeEnum.i32, BCTypeEnum.c8, BCTypeEnum.c16, BCTypeEnum.c32, BCTypeEnum.f23, BCTypeEnum.u32, BCTypeEnum.u16, BCTypeEnum.u8]))
            Store32(heapRef.u32, hrv);
        // since the stuff below are heapValues we may not want to do this??
        else if (hrv.type.type.anyOf([BCTypeEnum.Struct, BCTypeEnum.Slice, BCTypeEnum.Array, BCTypeEnum.string8]))
            MemCpy(heapRef.u32, hrv.u32, imm32(_sharedCtfeState.size(hrv.type)));
        else
            bailout(enumToString(hrv.type.type) ~ " is not supported in StoreToHeapRef");


    }

    void linkRefsCallee(VarDeclarations* parameters)
    {
        foreach (p; *parameters)
        {
            if (p.storage_class & STC.ref_)
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
    /// This sets up SliceDescriptors for multi dimensional arrays
    /// e.g. int[4][16][9];
    void setArraySliceDesc(BCValue arr, BCArray arrayType)
    {
        debug (NullAllocCheck)
        {
            Assert(arr.i32, addError(lastLoc, "trying to set sliceDesc null Array"));
        }

        auto offset = genTemporary(i32Type);
        scope(exit) destroyTemporary(offset);

        Comment("Add SliceDescriptor.Size");
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

    /// writes a default initalized array of a given type into the given base-offset
    bool genDefaultArray(BCValue base, BCType arrayType)
    {
        assert(arrayType.type == BCTypeEnum.Array, "this function expects an array type");
        BCArray _array = _sharedCtfeState.arrayTypes[arrayType.typeIndex - 1];

        const elemType = _array.elementType;
        BCValue defaultValue;

        const heapAdd = _sharedCtfeState.size(elemType);

        if (elemType.type.anyOf(smallIntegerTypes)
            || elemType.type.anyOf([BCTypeEnum.i32]))
        {
            defaultValue = imm32(0);
            defaultValue.type = elemType;

            ArrayBroadcast(base, imm32(_array.length), arrayType, defaultValue);
        }
        else
        {
            bailout("We don't support this initalizer-type yet" ~ enumToString(elemType.type));
            return false;
        }

        return true;
    }

    /// broadcasts an element to an array
    void ArrayBroadcast(BCValue base, BCValue length, BCType array_or_slice, BCValue broadCastElem, int line = __LINE__)
    {
        BCValue arrayLength;
        BCType elType;
        int heapAdd = -1;
        if (array_or_slice.type == BCTypeEnum.Array)
        {
            BCArray array = _sharedCtfeState.arrayTypes[array_or_slice.typeIndex - 1];
            elType = array.elementType;
            arrayLength = imm32(array.length);
        }
        else if (array_or_slice.type == BCTypeEnum.Slice)
        {
            BCSlice slice = _sharedCtfeState.sliceTypes[array_or_slice.typeIndex - 1];
            elType = slice.elementType;
            arrayLength = length;
        }
        heapAdd = _sharedCtfeState.size(elType, true);

        Comment("Broadcast_Assignment from: " ~ itos(line));
        BCValue ea = genTemporary(i32Type);
        scope(exit) destroyTemporary(ea);

        BCValue cpyCounter = genTemporary(i32Type);
        scope(exit) destroyTemporary(cpyCounter);

        bailout(broadCastElem.type != elType,
            "ArrayBroadCast array.elementType(" ~ _sharedCtfeState.typeToString(elType) ~
                ") and broadcastElem(" ~ _sharedCtfeState.typeToString(broadCastElem.type) ~
            ") mismatch ... "
        );

        Set(ea, base.i32); // ea = &array[0]
        {
            auto Lbegin = genLabel(); // LBegin:
            Lt3(BCValue.init, cpyCounter, arrayLength); // flag = cpyCounter < array.length
            auto cjContinue = beginCndJmp(BCValue.init);  // if (!flag) goto Lend;
            {
                Add3(cpyCounter, cpyCounter, imm32(1)); // cpyCounter++;
                {
                    broadCastElem.heapRef = BCHeapRef(ea);
                    StoreToHeapRef(broadCastElem);
                }  // *ea = broadCastElem;

                Add3(ea, ea, imm32(heapAdd)); // ea += elementSize
                endJmp(beginJmp(), Lbegin); // goto Lbegin;
            }
            auto Lend = genLabel();// Lend:
            endCndJmp(cjContinue, Lend);

            // this line sets the Lend in "if (!flag) goto Lend;" above
        }

    }

    /// Params: structPtr = assumed to point to already allocated memory
    ///         type = a pointer to the BCStruct, if none the type in the structPtr is used.
    void initStruct(BCValue structPtr, BCStruct* type = null, int line = __LINE__)
    {
        if (!type)
        {
            assert(structPtr.type.type == BCTypeEnum.Struct, "when no explicit type is passed we need the type in the bcvalue");
            type = &_sharedCtfeState.structTypes[structPtr.type.typeIndex - 1];
        }
        Comment("initStruct from " ~ itos(line));
        /// TODO FIXME this has to copy the struct intializer if there is one
        uint memberCount = type.memberCount;
        foreach(size_t i_, mt; type.memberTypes[0 .. memberCount])
        {
            if (mt.type == BCTypeEnum.Undef)
            {
                bailout("Unsupported type in struct");
                return ;
            }
            uint i = cast(uint)i_;
            // printf("structInitForMember %.*s\n", cast(int)_sharedCtfeState.typeToString(mt).length, _sharedCtfeState.typeToString(mt).ptr);
            Comment("StructInitForMember: " ~ _sharedCtfeState.typeToString(mt));
            auto pointerToMemberType = _sharedCtfeState.pointerOf(mt);
            if (mt.type == BCTypeEnum.Array)
            {
                auto offset = genTemporary(pointerToMemberType);
                scope(exit) destroyTemporary(offset);

                Add3(offset.u32, structPtr.u32, imm32(type.offset(cast(int)i), false));
                setArraySliceDesc(offset.u32, _sharedCtfeState.arrayTypes[mt.typeIndex - 1]);
                auto base = getBase(offset.u32);
                Comment("Array intialisation");
                auto offset2 = genTemporary(i32Type);
                scope(exit) destroyTemporary(offset2);

                auto initExp = type.initializerExps[i];
                auto initValue = initExp ? genExpr(type.initializerExps[i]) : BCValue.init;

                if (!initExp)
                {
                    if (!genDefaultArray(base, mt))
                        return ;
                }
                else if (!initValue) // implies the initExp was not null.
                {
                    bailout("structInitValue could not be genrated");
                    return ;
                }
                else // implies we could generate an initValue
                {
                    BCArray _array = _sharedCtfeState.arrayTypes[mt.typeIndex - 1];
                    const elemTypeSize = _sharedCtfeState.size(_array.elementType);

                    if (initValue.type.type == BCTypeEnum.Array)
                    {
                        auto initBase = getBase(initValue);
                        copyArray(&base, &initBase, getLength(initValue), elemTypeSize);
                    }
                    else
                    {
                        ArrayBroadcast(base, imm32(_array.length), mt, initValue);
                    }
                }

                Comment("Array intialisation End");
            }
            else if (mt.type == BCTypeEnum.string8)
            {
                auto initExp = type.initializerExps[i];
                auto initValue = initExp ? genExpr(type.initializerExps[i]) : BCValue.init;
                if (!initExp)
                {
                    // not init for this string.
                    initValue = imm32(type.offset(i));
                }
                auto offset = genTemporary(pointerToMemberType);
                scope(exit) destroyTemporary(offset);
                Add3(offset.u32, structPtr.u32, imm32(type.offset(i)));
                Store32(offset.u32, initValue);
            }
            else if (mt.type == BCTypeEnum.Slice)
            {
                auto sliceType = _sharedCtfeState.sliceTypes[mt.typeIndex - 1];
                Comment("Gen slice initializer");
                BCValue initValue = type.initializerExps[i] ? genExpr(type.initializerExps[i]) : BCValue.init;

                if (initValue)
                {
                    BCValue srcLength = getLength(initValue);
                    auto offset = genTemporary(pointerToMemberType);
                    scope(exit) destroyTemporary(offset);
                    Add3(offset.u32, structPtr.u32, imm32(type.offset(i), false));
                    auto sliceMemSize = AllocSlice(offset, srcLength, mt);
                    MemCpy(getBase(offset), getBase(initValue), sliceMemSize);
                }
            }
            else if (mt.type == BCTypeEnum.Struct)
            {
                auto offset = genTemporary(pointerToMemberType);
                scope(exit) destroyTemporary(offset);
                Add3(offset.u32, structPtr.u32, imm32(type.offset(i)));
                initStruct(offset, &_sharedCtfeState.structTypes[mt.typeIndex - 1]);
            }
            else if (mt.type == BCTypeEnum.Class)
            {
                auto offset = genTemporary(pointerToMemberType);
                Add3(offset.u32, structPtr.u32, imm32(type.offset(i)));
                auto initExp = type.initializerExps[i];
                BCValue initValue = initExp ? genExpr(type.initializerExps[i]) : imm32(0);
                Store32(offset.u32, initValue);

            }
            else if (mt.type == BCTypeEnum.u32 || mt.type == BCTypeEnum.i32 || mt.type == BCTypeEnum.f23)
            {
                BCValue initValue = type.initializerExps[i] ? genExpr(type.initializerExps[i]) : imm32(0);
                auto offset = genTemporary(pointerToMemberType);
                scope(exit) destroyTemporary(offset);
                Add3(offset.u32, structPtr.u32, imm32(type.offset(i)));
                Store32(offset.u32, initValue);
            }
            else if (mt.type == BCTypeEnum.u64 || mt.type == BCTypeEnum.i64 || mt.type == BCTypeEnum.f52)
            {
                BCValue initValue = type.initializerExps[i] ? genExpr(type.initializerExps[i]) : imm64(0);
                auto offset = genTemporary(pointerToMemberType);
                scope(exit) destroyTemporary(offset);
                Add3(offset.u32, structPtr.u32, imm32(type.offset(i)));
                Store64(offset.u32, initValue);
            }
            else
            {
                bailout("StructInitializer could not be generated for member-type: " ~ _sharedCtfeState.typeToString(mt));
                return ;
            }
        }
    }

    override void visit(VarExp ve)
    {
        lastLoc = ve.loc;

        File(fromStringz(ve.loc.filename));
        Line(ve.loc.linnum);
        auto vd = ve.var.isVarDeclaration;
        auto symd = ve.var.isSymbolDeclaration;
        auto fd = ve.var.isFuncDeclaration;

        debug (ctfe)
        {
            import std.stdio;

            writefln("VarExp %s discardValue %d", ve.toString, discardValue);
            if (vd && (cast(void*) vd) in vars)
                writeln("ve.var sp : ", ((cast(void*) vd) in vars).stackAddr);
        }

        import dmd.id : Id;
        if (ve.var.ident == Id.ctfe)
        {
            retval = imm32(1);
            return ;
        }
        else if (ve.var.ident == Id.dollar)
        {
            retval = getLength(currentIndexed);
            return ;
        }

        if (vd)
        {
            auto sv = getVariable(vd, ve);
            debug (ctfe)
            {
                //assert(sv, "Variable " ~ ve.toString ~ " not in StackFrame");
            }
/+
            if (sv.vType == BCValueType.VoidValue && !ignoreVoid)
            {
                Assert(imm32(0), addError(ve.loc, "Trying to to read from an uninitialized variable " ~ ve.toString));
                // bailout("Trying to read form an uninitialized variable: " ~ ve.toString);
                //TODO ve.error here ?
                return ;
            }
+/
            if (sv == BCValue.init)
            {
                bailout("invalid variable value");
                return ;
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
            // import std.stdio; import dmd.asttypename; writeln("Symbol variable exp: ", sd.astTypeName());//DEBUGLINE

            Expressions iexps;

            foreach (ie; *sd.members)
            {
                //iexps.push(new Expression();
            }
            auto sl = new StructLiteralExp(symd.loc, sd, &iexps);
            retval = genExpr(sl);
            //assert(0, "SymbolDeclarations are not supported for now" ~ .type.size.itos);
            //auto vs = symd in syms;

        }
        else if (fd)
        {
            retval = imm32(_sharedCtfeState.getFunctionIndex(fd));
            retval.type.type = BCTypeEnum.Function;
        }
        else
        {
            import dmd.asttypename;
            assert(0, "VarExpType unkown: " ~ ve.var.astTypeName);
        }

        // static if (is(BCGen)) Prt(retval);

        debug (ctfe)
        {
            import std.stdio;

            writeln("VarExp finished");
        }
    }

    override void visit(DeclarationExp de)
    {
        lastLoc = de.loc;

        File(fromStringz(de.loc.filename));
        Line(de.loc.linnum);
        auto oldRetval = retval;
        auto vd = de.declaration.isVarDeclaration();

        if (!vd)
        {
            // It seems like we can ignore declarations that are not variables
            return ;
        }

        visit(vd);
        auto var = retval;
        if (!var)
        {
            bailout("var for declarartion could not be generated -- " ~ de.toString);
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
                var.couldBeVoid = true;
                setVariable(vd, var);
            }
            else if (auto ci = vd.getConstInitializer)
            {
                auto _init = genExpr(ci);
                if (_init.type.type == BCTypeEnum.u32)
                {
                    Set(var.u32, _init);
                }
                else if (_init.type.type == BCTypeEnum.i32)
                {
                    Set(var.i32, _init);
                }
                else if (_init.type.type == BCTypeEnum.f23)
                {
                    Set(var.u32, _init.u32);
                }
                else if (_init.type.type == BCTypeEnum.f52)
                {
                    Set(var, _init);
                }
                else if (_init.type.type == BCTypeEnum.Struct)
                {
                    //Set(var.i32, _init.i32);
                    //TODO we should really do a memcopy here instead of copying the pointer;
                    // Only do the memcpy if the initalizer is diffrent from var.
                    // I don't even know why init can be the same as var ... ah well.
                    if (var != _init)
                    {
                        MemCpy(var.u32, _init.u32, imm32(_sharedCtfeState.size(_init.type)));
                    }
                }
                else if (_init.type.type == BCTypeEnum.Class)
                {
                    Set(var.u32, _init.u32);
                }
                else if (_init.type.type == BCTypeEnum.Slice || _init.type.type == BCTypeEnum.Array || _init.type.type == BCTypeEnum.string8)
                {
                    // todo introduce a bool function passedByPtr(BCType t)
                    // maybe dangerous who knows ...
                    if (var.u32 != _init.u32)
                    MemCpy(var.u32, _init.u32, imm32(SliceDescriptor.Size));
                }
                else if (_init.type.type.anyOf(smallIntegerTypes))
                {
                    Set(var.i32, _init.i32);
                }
                else if (_init.type.type == BCTypeEnum.i64)
                {
                    Set(var, _init);
                }
                else if (_init.type.type == BCTypeEnum.u64)
                {
                    Set(var, _init);
                }
                else if (_init.type.type == BCTypeEnum.Ptr && var.type.type == BCTypeEnum.Ptr)
                {
                    MemCpy(var.i32, _init.i32, imm32(SliceDescriptor.Size));
                    //Set(var.i32, _init.i32);
                }
                else if (_init.type.type == BCTypeEnum.Function && var.type.type == BCTypeEnum.Function)
                {
                    Set(var.i32, _init.i32);
                }
                else
                {
                    bailout("We don't know how to deal with this initializer: " ~ _init.toString ~ " -- " ~ de.toString);
                }

            }
            retval = var;
        }
    }

    override void visit(VarDeclaration vd)
    {
        lastLoc = vd.loc;

        File(fromStringz(vd.loc.filename));
        Line(vd.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("VarDeclaration %s discardValue %d", vd.toString, discardValue);
        }

        BCValue var;
        BCType type = toBCType(vd.type);
        if (!type.type)
        {
            bailout("could not get type for:" ~ vd.toString);
            return ;
        }

        if (processingParameters)
        {
            if (vd.storage_class & STC.ref_)
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
                Alloc(var.i32, imm32(SliceDescriptor.Size), type);
            }
            else if (type.type == BCTypeEnum.Array)
            {
                Alloc(var.i32, imm32(_sharedCtfeState.size(type)), type);
                assert(type.typeIndex);
                auto arrayType = _sharedCtfeState.arrayTypes[type.typeIndex - 1];
                setArraySliceDesc(var, arrayType);
            }
            else if (type.type == BCTypeEnum.Struct)
            {
                Alloc(var.i32, imm32(_sharedCtfeState.size(type)), type);
            }
        }

        setVariable(vd, var);
        retval = var;
    }

    void setVariable(VarDeclaration vd, BCValue var, bool inClosure = false)
    {
        vars[cast(void*) vd] = var;
    }

    void setClosureVarOffset(VarDeclaration vd, uint offset)
    {
        assert(offset, "offset can never be 0");
        closureVarOffsets[cast(void*) vd] = offset;
    }

    static bool canHandleBinExpTypes(const BCTypeEnum lhs, const BCTypeEnum rhs) pure
    {
        return ((lhs == BCTypeEnum.i32 || lhs == BCTypeEnum.u32 || lhs == BCTypeEnum.u64 || lhs == BCTypeEnum.i64 ||
                 lhs == BCTypeEnum.f23 || lhs == BCTypeEnum.f52) && rhs == lhs) 
            || (lhs == BCTypeEnum.u32 || lhs == BCTypeEnum.u64 || lhs == BCTypeEnum.i32 || lhs == BCTypeEnum.i64) && 
               (rhs == BCTypeEnum.u32 || rhs == BCTypeEnum.u64 || rhs == BCTypeEnum.i32 || rhs == BCTypeEnum.i64)
            || (lhs == BCTypeEnum.i64 && (rhs == BCTypeEnum.i32 || rhs == BCTypeEnum.i64));
    }

    override void visit(BinAssignExp e)
    {
        lastLoc = e.loc;

        File(fromStringz(e.loc.filename));
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
            return ;
        }

        auto common_ty = commonTypeEnum(lhs.type.type, rhs.type.type);
        bool uns = (common_ty >= BCTypeEnum.u8 && common_ty <= BCTypeEnum.u64);

        if (e.op == TOK.concatenateAssign) // cat of two slices
        {
            const elemType = _sharedCtfeState.elementType(lhs.type);
            // a ~= b;
            // newLength = a.length + b.length
            // neededSize = (newLength * elemSize) + SliceDescriptor.Size;
            // if (a.capacity < neededSize)
            // {
            // ExtraCapa = b.length * (32*elemSize));
            // allocSize = neededSize + ExtraCapa;
            // newBase = alloc(allocSize);
            // newCapa = allocSize
            //}
            // we have enough space for the size needed
            //

            import dmd.ctfe.bc_abi : SliceDescriptor;
            // here we can use capcity and such ...
            const oldBase = getBase(lhs);
            const capa = getCapacity(lhs);
            scope (exit) destroyTemporary(capa);
            const elemSize = _sharedCtfeState.size(elemType, true);
            const elemSizeImm32 = imm32(elemSize);

            BCValue newBase = genTemporary(i32Type);
            scope(exit) destroyTemporary(newBase);
            Set(newBase, oldBase);

            auto newLength = genTemporary(i32Type);
            scope(exit) destroyTemporary(newLength);

            auto lhs_length = getLength(lhs);
            auto rhs_length = getLength(rhs);
            auto rhs_base   = getBase(rhs);
            Add3(newLength, lhs_length, rhs_length);
            scope (exit)
            {
                destroyTemporary(lhs_length);
                if (rhs_length.vType != BCValueType.Immediate)
                    destroyTemporary(rhs_length);
                if (rhs_base.vType != BCValueType.Immediate)
                    destroyTemporary(rhs_base);
            }

            auto neededSize = genTemporary(i32Type);
            scope(exit) destroyTemporary(neededSize);

            Mul3(neededSize, newLength, elemSizeImm32);
            Add3(neededSize, neededSize, imm32(SliceDescriptor.Size));

            BCValue sliceDescPtr = genTemporary(lhs.type);
            Set(sliceDescPtr.i32, lhs.i32);
            {
                auto ifRet = If(neededSize, &Gt3, capa);
                {
                    auto allocSize = genTemporary(i32Type);
                    scope(exit) destroyTemporary(allocSize);
                    Mul3(allocSize, rhs_length, imm32(elemSize * 32));
                    Add3(allocSize, allocSize, neededSize);

                    Alloc(sliceDescPtr.i32, allocSize, lhs.type);
                    Add3(newBase, sliceDescPtr.i32, imm32(SliceDescriptor.Size));
                    setBase(sliceDescPtr, newBase);
                    setCapacity(sliceDescPtr, allocSize);
                    auto lhsDataSize = genTemporary(i32Type);
                    scope(exit) destroyTemporary(lhsDataSize);
                    Mul3(lhsDataSize, lhs_length, imm32(elemSize));

                    MemCpy(newBase, oldBase, lhsDataSize);
                }
                EndIf(ifRet);
            }
            // new we have enough memory to copy b into the memory after a
            BCValue copyDestPtr = genTemporary(i32Type);
            scope(exit) destroyTemporary(copyDestPtr);
            Mul3(copyDestPtr, lhs_length, elemSizeImm32);
            Add3(copyDestPtr, copyDestPtr, newBase);

            BCValue rhsDataSize = genTemporary(i32Type);
            scope(exit) destroyTemporary(rhsDataSize);
            Mul3(rhsDataSize, rhs_length, imm32(elemSize));

            MemCpy(copyDestPtr, rhs_base, rhsDataSize);
            // set the new length
            setLength(sliceDescPtr, newLength);
            Set(lhs.i32, sliceDescPtr.i32);

            retval = lhs;

            //doCat(lhs, lhs, rhs);

        }
        else if (e.op == TOK.concatenateElemAssign) // cat of elem and slice
        {
            if ((lhs.type.type == BCTypeEnum.Slice && lhs.type.typeIndex < _sharedCtfeState.sliceTypes.length) || lhs.type.type == BCTypeEnum.string8)
            {
                const elemType = _sharedCtfeState.elementType(lhs.type);
                if (elemType == rhs.type)
                {
                    const oldBase = getBase(lhs);
                    const capa = getCapacity(lhs);
                    scope (exit) destroyTemporary(capa);
                    const elemSize = _sharedCtfeState.size(elemType);
                    const elemSizeImm32 = imm32(elemSize);

                    BCValue newBase = genTemporary(i32Type);
                    Set(newBase, oldBase);
                    auto len = getLength(lhs);
                    auto dataSize = genTemporary(i32Type);
                    scope(exit) destroyTemporary(dataSize);
                    Mul3(dataSize, len, imm32(elemSize));

                    auto newSize = genTemporary(i32Type);
                    scope(exit) destroyTemporary(newSize);

                    Add3(len, len, imm32(1));
                    Mul3(newSize, len, elemSizeImm32);
                    Add3(newSize, newSize, imm32(SliceDescriptor.Size));

                    BCValue sliceDescPtr = genTemporary(lhs.type);
                    Set(sliceDescPtr.i32, lhs.i32);
                    {
                        auto ifRet = If(newSize, &Gt3, capa);
                        {
                            auto allocSize = genTemporary(i32Type);
                            Add3(allocSize, newSize, imm32(elemSize * 32));

                            Alloc(sliceDescPtr.i32, allocSize, lhs.type);

                            Add3(newBase, sliceDescPtr.i32, imm32(SliceDescriptor.Size));

                            setBase(sliceDescPtr, newBase);
                            setCapacity(sliceDescPtr, allocSize);
                            MemCpy(newBase, oldBase, dataSize);
                        }
                        EndIf(ifRet);
                    }
                    BCValue nextElemPtr = genTemporary(i32Type);
                    scope(exit) destroyTemporary(nextElemPtr);

                    Add3(nextElemPtr, newBase, dataSize);
                    SetMem(nextElemPtr, rhs);
                    setLength(sliceDescPtr, len);
                    Set(lhs.i32, sliceDescPtr.i32);
                }
            }
            else
                bailout("We could not gen code for ~=");

        }
        else if (!canHandleBinExpTypes(lhs.type.type, rhs.type.type))
        {
            //printf("tok: %s\n", enumToString(e.op).ptr);
            bailout("Cannot use binExpTypes: " ~ enumToString(lhs.type.type) ~ " et: " ~ _sharedCtfeState.typeToString(_sharedCtfeState.elementType(lhs.type))  ~ " -- " ~ enumToString(rhs.type.type) ~ " et : " ~
_sharedCtfeState.typeToString(_sharedCtfeState.elementType(rhs.type)) ~ " -- " ~ e.toString);
            return ;
        }
        else switch (e.op)
        {
        case TOK.addAssign:
            {
                Add3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.minAssign:
            {
                Sub3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;

        case TOK.orAssign:
            {
                 static if (is(BCGen))
                     if (lhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.i32)
                        bailout("BCGen does not suppport 32bit bit-operations");

                Or3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.andAssign:
            {
                And3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.xorAssign:
            {
                Xor3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.rightShiftAssign:
            {
                static if (is(BCGen))
                    if (lhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.i32)
                        bailout("BCGen does not suppport 32bit bit-operations");

                Rsh3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.leftShiftAssign:
            {
//                static if (is(BCGen))
//                    if (lhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.i32)
//                        bailout("BCGen does not suppport 32bit bit-operations");

                Lsh3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.mulAssign:
            {
                Mul3(lhs, lhs, rhs);
                retval = lhs;
            }
            break;
        case TOK.divAssign:
            {
                if (uns)
                {
                    Udiv3(lhs, lhs, rhs);
                }
                else
                {
                    Div3(lhs, lhs, rhs);
                }
                retval = lhs;
            }
            break;
        case TOK.modAssign:
            {
                if (uns)
                {
                    Umod3(lhs, lhs, rhs);
                }
                else
                {
                    Mod3(lhs, lhs, rhs);
                }
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
        lastLoc = ie.loc;

        File(fromStringz(ie.loc.filename));
        Line(ie.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("IntegerExpression %s", ie.toString);
        }

        auto bct = toBCType(ie.type);
        if (bct.type != BCTypeEnum.i32 && bct.type != BCTypeEnum.i64 && bct.type != BCTypeEnum.c8 &&
            bct.type != BCTypeEnum.c32 && bct.type != BCTypeEnum.i8 && bct.type != BCTypeEnum.u32 &&
            bct.type != BCTypeEnum.u64 && bct.type != BCTypeEnum.u8)
        {
            //NOTE this can happen with cast(char*)size_t.max for example
            bailout("We don't support IntegerExpressions with non-integer types: " ~ enumToString(bct.type));
        }

        if (bct.type == BCTypeEnum.i64)
        {
            retval = BCValue(Imm64(ie.getInteger()));
        }
        else if (bct.type == BCTypeEnum.u64)
        {
            retval = BCValue(Imm64(cast(ulong)ie.getInteger(), false));
        }
        else
        {
            if (ie.type.ty == Tuns32)
            {
                retval = BCValue(Imm32(cast(uint)ie.getInteger(), false));
                retval.type = bct;
            }
            else
            {
                retval = imm32(cast(int) ie.getInteger());
                retval.type = bct;
            }
        }
        //auto value = evaluateUlong(ie);
        //retval = value <= int.max ? imm32(cast(uint) value) : BCValue(Imm64(value));
        assert(retval.vType == BCValueType.Immediate);
    }

    override void visit(RealExp re)
    {
        lastLoc = re.loc;

        File(fromStringz(re.loc.filename));
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
            bailout("RealExp of type " ~ enumToString(cast(TY)re.type.ty)
                ~ " unsupported");
    }

    override void visit(ComplexExp ce)
    {
        lastLoc = ce.loc;

        File(fromStringz(ce.loc.filename));
        Line(ce.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ComplexExp %s", ce.toString);
        }

        bailout("ComplexExp unsupported");
    }

    override void visit(StringExp se)
    {
        lastLoc = se.loc;

        File(fromStringz(se.loc.filename));
        Line(se.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("StringExp %s", se.toString);
        }

        scope argVisitor = new BCArgumentVisitor();
        argVisitor.visit(se);
        auto stringAddr = argVisitor.result;

        assert(!inArgumentProcessing);
        {
            retval = assignTo ? assignTo : genTemporary(BCType(BCTypeEnum.string8));
            Set(retval.i32, stringAddr.i32);
        }
    }

    override void visit(CmpExp ce)
    {
        lastLoc = ce.loc;

        File(fromStringz(ce.loc.filename));
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

        auto common_ty = commonTypeEnum(lhs.type.type, rhs.type.type);

        bool uns = (common_ty >= BCTypeEnum.u8 && common_ty <= BCTypeEnum.u64);


        if (canWorkWithType(lhs.type) && canWorkWithType(rhs.type) && (!oldAssignTo || canWorkWithType(oldAssignTo.type)))
        {
            switch (ce.op)
            {
            case TOK.lessThan:
                {
                    uns ? Ult3(oldAssignTo, lhs, rhs) : Lt3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            case TOK.greaterThan:
                {
                    uns ? Ugt3(oldAssignTo, lhs, rhs) : Gt3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            case TOK.lessOrEqual:
                {
                    uns ? Ule3(oldAssignTo, lhs, rhs) : Le3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            case TOK.greaterOrEqual:
                {
                    uns ? Uge3(oldAssignTo, lhs, rhs) : Ge3(oldAssignTo, lhs, rhs);
                    retval = oldAssignTo;
                }
                break;

            default:
                bailout("Unsupported comparison " ~ enumToString(ce.op));
            }
        }
        else
        {
            bailout(
                "CmpExp: cannot work with these types lhs: " ~ enumToString(lhs.type.type) ~ " rhs: " ~ enumToString(
                rhs.type.type) ~ " result: " ~ enumToString(oldAssignTo.type.type) ~ " -- " ~  ce.toString);
        }
    }

    static bool canWorkWithType(const BCType bct) pure
    {
        return (bct.type.anyOf([BCTypeEnum.c8, BCTypeEnum.c16, BCTypeEnum.c32,
                                BCTypeEnum.i8, BCTypeEnum.i16, BCTypeEnum.i32, BCTypeEnum.i64,
                                BCTypeEnum.u8, BCTypeEnum.u16, BCTypeEnum.u32, BCTypeEnum.u64,
                                BCTypeEnum.f23, BCTypeEnum.f52]));
    }
/+
    override void visit(ConstructExp ce)
    {
        lastLoc = ce.loc;

        File(fromStringz(ce.loc.filename));
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
            return ;
        }

        auto lhs = genExpr(ce.e1);
        auto rhs = genExpr(ce.e2);

        if (!lhs)
        {
            bailout("could not gen " ~ ce.e1.toString);
            return ;
        }

        if (!rhs)
        {
            bailout("could not gen " ~ ce.e2.toString);
            return ;
        }

        // do we deal with an int?
        if (lhs.type.type == BCTypeEnum.i32)
        {

        }
        else if (lhs.type.type == BCTypeEnum.string8
            || lhs.type.type == BCTypeEnum.Slice || lhs.type.type.Array)
        {

        }
        else if (lhs.type.type == BCTypeEnum.c8 || lhs.type.type == BCTypeEnum.i8)
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
            assert(lhs.type.type == BCTypeEnum.Struct, enumToString(lhs.type.type));

        }
        Set(lhs.i32, rhs.i32);
        retval = lhs;
    }
+/

    override void visit(AssignExp ae)
    {
        lastLoc = ae.loc;

        File(fromStringz(ae.loc.filename));
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

        if (ae.e1.op == TOK.slice && ae.e2.op == TOK.slice)
        {
            SliceExp e1 = cast(SliceExp)ae.e1;
            SliceExp e2 = cast(SliceExp)ae.e2;

            auto lhs = genExpr(e1);
            auto rhs = genExpr(e2);

            auto lhs_base = getBase(lhs);
            auto rhs_base = getBase(rhs);

            if (lhs_base.vType != BCValueType.Immediate)
                destroyTemporary(lhs_base);
            if (rhs_base.vType != BCValueType.Immediate)
                destroyTemporary(rhs_base);

            auto lhs_length = getLength(lhs);
            auto rhs_length = getLength(rhs);

            if (lhs_length.vType != BCValueType.Immediate)
                destroyTemporary(lhs_length);
            if (rhs_length.vType != BCValueType.Immediate)
                destroyTemporary(rhs_length);

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
                auto ifRet = If(lhs_length, &Neq3, rhs_length);
                {
                    Assert(imm32(0), 
                        addError(ae.loc, "array length mismatch assigning [%d..%d] to [%d..%d]", rhs_lwr, rhs_upr, lhs_lwr, lhs_upr));
                }
                EndIf(ifRet);
            }

            auto elemSize = sharedCtfeState.size(sharedCtfeState.elementType(lhs.type));

            if (!elemSize)
            {
                bailout("could not get elementSize of: " ~ _sharedCtfeState.typeToString(lhs.type));
                return ;
            }

            auto overlapError = addError(ae.loc, "overlapping slice assignment [%d..%d] = [%d..%d]", lhs_lwr, lhs_upr, rhs_lwr, rhs_upr);

            // const diff = ptr1 > ptr2 ? ptr1 - ptr2 : ptr2 - ptr1;
            auto ptr_diff = genTemporary(i32Type);
            scope(exit) destroyTemporary(ptr_diff);
            {
                auto ifRet = If(lhs_base, &Gt3, rhs_base);
                {
                    Sub3(ptr_diff, lhs_base, rhs_base);
                }
                auto elseRet = Else(ifRet);
                {
                    Sub3(ptr_diff, rhs_base, lhs_base);
                }
                EndElse(elseRet);
            }

            auto arraySize = genTemporary(i32Type);
            scope(exit) destroyTemporary(arraySize);
            Mul3(arraySize, lhs_length, imm32(elemSize));

            {
                // if(ptr_diff < length) assert(0, overlapError);
                auto ifRet = If(ptr_diff, &Lt3, arraySize);
                {
                    Assert(imm32(0), overlapError);
                }
                EndIf(ifRet);
            }
            MemCpy(lhs_base, rhs_base, arraySize);
        }

        debug (ctfe)
        {
            import std.stdio;
            writeln("OP: ", ae.op.enumToString);
            writeln("ae.e1.op ", enumToString(ae.e1.op));
        }

        if (ae.e1.op == TOK.dotVariable)
        {
            // Assignment to a struct or class member
            // needs to be handled differently
            auto dve = cast(DotVarExp) ae.e1;
            auto aggregate = dve.e1;
            auto aggTy = aggregate.type.ty;


            if (aggTy != Tstruct && aggTy != Tclass)
            {
                bailout("only structs and classes are supported for now");
                return ;
            }

            auto isStruct = (aggTy == Tstruct);

            auto structDeclPtr = (cast(TypeStruct) aggregate.type).sym;
            auto classDeclPtr = (cast(TypeClass) aggregate.type).sym;

            auto aggregateTypeIndex =
                (isStruct ? _sharedCtfeState.getStructIndex(structDeclPtr)
                          : _sharedCtfeState.getClassIndex(classDeclPtr));

            auto aggBCType = toBCType(aggregate.type);

            if (!aggregateTypeIndex)
            {
                bailout("could not get Type of struct or class");
                return ;
            }

            auto vd = dve.var.isVarDeclaration();
            assert(vd);

            import dmd.ctfeexpr : findFieldIndexByName;

            auto fInfo = getFieldInfo(aggBCType, vd);

            // this can happen on forward-references
            if(fInfo.offset == -1)
            {
                bailout("field " ~ vd.toString ~ " could not be found in " ~ dve.e1.toString);
                return ;
            }

            if (fInfo.type == BCType.init)
            {
                bailout("could not get field-type for -- " ~ dve.e1.toString);
                return ;
            }

            // import std.stdio; writeln("got fieldType: ", fieldType); //DEBUGLINE

            string enumArrayToString(T)(T arr)
            {
                static assert(is(typeof(arr[0]) == enum),
                    "enumArrayToString is only meant to be called with arrays of enums");

                string result = "[";
                foreach(e;arr)
                {
                    result ~= enumToString(e) ~ ", ";
                }
                result = result[0 .. $-2] ~ "]";

                return result;
            }

            static immutable supportedStructTypes =
            () {
                with(BCTypeEnum)
                {
                    return [i8, u8, i32, u32, i64, u64, f23, f52, string8, Function, Delegate, Class, Struct, Ptr];
                }
            } ();

            const typeEnum = fInfo.type.type;
            if (!typeEnum.anyOf(supportedStructTypes))
            {
                bailout("only " ~ enumArrayToString(supportedStructTypes) ~ " are supported for structs (for now)... not : " ~ enumToString(typeEnum));
                return ;
             }

            auto lhs = genExpr(aggregate);
            if (!lhs)
            {
                bailout("could not gen: " ~ aggregate.toString);
                return ;
            }

            auto rhs = genExpr(ae.e2);
            if (!rhs)
            {
                //Not sure if this is really correct :)
                rhs = bcNull;
            }
/+
            {
                if (bcStructType.voidInit[fIndex])
                {
                    // set member to be inited.
                    setMemberVoidInit(lhs, fIndex, true);
                }
            }
+/
            if (!rhs.type.type.anyOf(supportedStructTypes))
            {
                bailout("only " ~ enumArrayToString(supportedStructTypes) ~ " are supported for now. Not:" ~ rhs.type.type.enumToString);
                return ;
            }


            auto ptr = genTemporary(rhs.type);

            auto offset = fInfo.offset;

            Add3(ptr, lhs.i32, imm32(offset));

            SetMem(ptr, rhs);

            retval = rhs;
            destroyTemporary(ptr);
        }
        else if (ae.e1.op == TOK.arrayLength)
        {
            assert(0, "Since a while length assignments are rewritten to a functionCall");
        }
        else if (ae.e1.op == TOK.index)
        {
            auto ie1 = cast(IndexExp) ae.e1;

            auto indexed = genExpr(ie1.e1, "AssignExp.e1(indexExp).e1 (e1[x])");
            if (!indexed)
            {
                bailout("could not fetch indexed_var in " ~ ae.toString);
                return ;
            }
            auto index = genExpr(ie1.e2, "AssignExp.e1(indexExp).e2: (x[e2])");
            if (!index)
            {
                bailout("could not fetch index in " ~ ae.toString);
                return ;
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
            Assert(effectiveAddr.i32, addError(lastLoc, "No effetive addr in -- " ~ ae.toString));

            SetMem(effectiveAddr, rhs);
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
                return ;
            }


            if ((lhs.type.type == BCTypeEnum.i32 || lhs.type.type == BCTypeEnum.u32) && (rhs.type.type == BCTypeEnum.i32 || rhs.type.type == BCTypeEnum.u32))
            {
                //TODO we may need to sign Extend and we should provide an instruction to do so!
                Set(lhs, rhs);
            }
            else if ((lhs.type.type == BCTypeEnum.i64 || lhs.type.type == BCTypeEnum.u64) && (rhs.type.type == BCTypeEnum.i64 || rhs.type.type == BCTypeEnum.u64 || rhs.type.type == BCTypeEnum.i32))
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
                    bailout(!lhs.type.typeIndex || lhs.type.typeIndex > _sharedCtfeState.pointerCount, "pointer type invalid or not registered");
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
                else if (lhs.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.c8]) && rhs.type.type.anyOf([BCTypeEnum.i8, BCTypeEnum.c8]))
                {
                    Set(lhs.i32, rhs.i32);
                }
                else if ((lhs.type.type == BCTypeEnum.string8 && rhs.type.type == BCTypeEnum.string8) ||
                    (lhs.type.type == BCTypeEnum.Slice && rhs.type.type == BCTypeEnum.Array) ||
                    (lhs.type.type == BCTypeEnum.Slice && rhs.type.type == BCTypeEnum.Slice))
                {
/+ This is probably not needed ....
                    if (ae.op == TOK.construct)
                    {
                        auto CJLhsIsNull = beginCndJmp(lhs.i32, true);
                        Alloc(lhs.i32, imm32(SliceDescriptor.Size));
                        endCndJmp(CJLhsIsNull, genLabel());
                    }
+/
                    MemCpy(lhs.i32, rhs.i32, imm32(SliceDescriptor.Size));
                }
                else if (lhs.type.type == BCTypeEnum.Delegate && rhs.type.type == BCTypeEnum.Delegate)
                {
                    MemCpy(lhs.i32, rhs.i32, imm32(basicTypeSize(BCTypeEnum.Delegate)));
                }
                else if (lhs.type.type == BCTypeEnum.Array && rhs.type.type == BCTypeEnum.Array)
                {
                    auto lhsBase = getBase(lhs);
                    auto rhsBase = getBase(rhs);
                    auto lhsLength = getLength(lhs);
                    auto rhsLength = getLength(rhs);
                    auto sameLength = genTemporary(i32Type);
                    auto lhsBaseType = _sharedCtfeState.elementType(lhs.type);

                    Eq3(sameLength, lhsLength, rhsLength);
                    Assert(sameLength, addError(ae.loc, "%d != %d", rhsLength, lhsLength));

                    copyArray(&lhsBase, &rhsBase, lhsLength, _sharedCtfeState.size(lhsBaseType));
                }
                else if ((lhs.type.type == BCTypeEnum.Slice || lhs.type.type == BCTypeEnum.string8) && rhs.type.type == BCTypeEnum.Null)
                {
                    // Technically this should have been an allocated slice desc.
                    // So all we need to do here is to zero it.
                    Assert(lhs.i32, addError(ae.loc, "When Zeroing the slice ptr is not allocated"));
                    setLength(lhs.i32, imm32(0));
                    setBase(lhs.i32, imm32(0));
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
                        ArrayBroadcast(base, imm32(arrayType.length), lhs.type, rhs);
                    }
                    else
                    {
                        bailout("ArrayAssignment unhandled: " ~ ae.toString);
                        return ;
                    }
                }
                else if (lhs.type.type == BCTypeEnum.Struct && rhs.type.type == BCTypeEnum.i32 && rhs.imm32 == 0)
                {
                    if(!lhs.type.typeIndex || lhs.type.typeIndex > _sharedCtfeState.structCount)
                    {
                        bailout("StructType is invalid: " ~ ae.e1.toString);
                        return ;
                    }
                    if (!_sharedCtfeState.size(lhs.type))
                    {
                        bailout("StructType has invalidSize (this is really bad): " ~ ae.e1.toString);
                        return ;
                    }
                    auto structType = &_sharedCtfeState.structTypes[lhs.type.typeIndex - 1];

                    // HACK allocate space for struct if structPtr is zero
                    auto JstructNotNull = beginCndJmp(lhs.i32, true);
                    auto structSize = _sharedCtfeState.size(lhs.type);
                    Alloc(lhs.i32, imm32(structType.size), lhs.type);
                    endCndJmp(JstructNotNull, genLabel());
                    initStruct(lhs, structType);
                }
                else if (lhs.type.type == BCTypeEnum.Struct && rhs.type.type == BCTypeEnum.Struct)
                {
                    //FIXME this might be wrong ... if it is determined that it is not; remove this FIXME

                    //Struct Assiignment involves allocation and copying ... sigh
                    if (lhs.type.typeIndex != rhs.type.typeIndex)
                    {
                        bailout("We tried to assign a struct to a struct of a diffrent type -- "
                            ~ ae.toString());
                        return ;
                    }

                    const structSize = _sharedCtfeState.size(lhs.type);
                    const allocSize = align4(structSize);

                    if (!allocSize)
                    {
                        bailout("We would do a null allocation in " ~ ae.toString);
                        return ;
                    }
/+
                    if (ae.op == TOK.construct)
                    {
                        auto CJLhsIsNull = beginCndJmp(lhs.i32, true);
                        Alloc(lhs.i32, imm32(allocSize), lhs.type);
                        endCndJmp(CJLhsIsNull, genLabel());
                    }
+/
                    MemCpy(lhs.i32, rhs.i32, imm32(structSize));
                }
                else if (lhs.type.type == BCTypeEnum.Class && rhs.type.type == BCTypeEnum.Class)
                {
                    Set(lhs.i32, rhs.i32);
                }
                else if (lhs.type.type == BCTypeEnum.Class && rhs.type.type == BCTypeEnum.Null)
                {
                    Set(lhs.i32, imm32(0));
                }
                else if ((lhs.type.type == BCTypeEnum.Slice && rhs.type == _sharedCtfeState.elementType(lhs.type))
                     || (lhs.type.type == BCTypeEnum.string8 && rhs.type.type == BCTypeEnum.c8))
                {
                    // this is a broadcast assignment to a slice
                    // TODO replace with  ArrayBroadcast(base, _array, defaultValue);
                    Comment("Broadcast Assignment (Slice)");
                    const elemType = _sharedCtfeState.elementType(lhs.type);
                    auto length = getLength(lhs);
                    BCValue idx = genTemporary(i32Type);
                    BCValue offset = genTemporary(i32Type);

                    if (isBasicBCType(elemType))
                    {
                        const elemTypeSize = basicTypeSize(elemType.type);
                        Set(offset, getBase(lhs));
                        auto isLessThan = genTemporary(i32Type);

                        auto LcondEval = genLabel();
                        Lt3(isLessThan, idx, length);
                        auto cjAtEnd = beginCndJmp(isLessThan);
                        {
                            elemTypeSize <= 4 ?
                                Store32(offset.i32, rhs):
                                Store64(offset.i32, rhs);

                            Add3(offset, offset, imm32(elemTypeSize));
                            Add3(idx, idx, imm32(1));
                            Jmp(LcondEval);
                        }
                        endCndJmp(cjAtEnd, genLabel());
                    }
                    else
                    {
                        bailout("currently only boardcast assignments of"
                            ~ "basic Types are supported");
                    }
                }
                else
                {
                    bailout( "I cannot work with these types " ~ enumToString(lhs.type.type) ~ " " ~ enumToString(rhs.type.type) ~ " -- " ~ ae.toString);  return ;
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
        lastLoc = _.loc;

        File(fromStringz(_.loc.filename));
        Line(_.loc.linnum);
        //assert(0, "encounterd SwitchErrorStatement" ~ toString(_));
    }

    override void visit(NegExp ne)
    {
        lastLoc = ne.loc;

        File(fromStringz(ne.loc.filename));
        Line(ne.loc.linnum);
        auto e1 = genExpr(ne.e1);
        retval = assignTo ? assignTo : genTemporary(toBCType(ne.type));
        auto zero = imm32(0);
        zero.type = e1.type;
        Sub3(retval, zero, e1);
    }

    override void visit(NotExp ne)
    {
        lastLoc = ne.loc;

        File(fromStringz(ne.loc.filename));
        Line(ne.loc.linnum);
        {
            retval = assignTo ? assignTo : genTemporary(i32Type);
            Eq3(retval, genExpr(ne.e1).i32, imm32(0));
        }

    }

    override void visit(UnrolledLoopStatement uls)
    {
        lastLoc = uls.loc;

        File(fromStringz(uls.loc.filename));
        Line(uls.loc.linnum);

        unrolledLoopState = unrolledLoopStack.push();
        scope (exit)
            unrolledLoopState = unrolledLoopStack.pop();

        uint end = cast(uint) uls.statements.dim - 1;

        foreach (stmt; *uls.statements)
        {
            auto block = genBlock(stmt, true, true);
            {
                foreach (fixup; unrolledLoopState.continueFixups[0 .. unrolledLoopState.continueFixupCount])
                {
                    //HACK the will leave a nop in the bcgen
                    //but it will break llvm or other potential backends;
                    if (fixup.addr != block.end.addr)
                        endJmp(fixup, block.end);
                }
                unrolledLoopState.continueFixupCount = 0;
            }

        }

        auto afterUnrolledLoop = genLabel();
        {
            //FIXME Be aware that a break fixup has to be checked against the ip
            //If there is an unrolledLoopStatement that has no statements in it,
            // we end up fixing the jump up to ourselves.
            foreach (fixup; unrolledLoopState.breakFixups[0 .. unrolledLoopState.breakFixupCount])
            {
                //HACK this will leave a nop in the bcgen
                //but it will break llvm or other potential backends;
                Comment("Putting unrolled_loopStatement-breakFixup");
                if (fixup.addr != afterUnrolledLoop.addr)
                    endJmp(fixup, afterUnrolledLoop);

            }
            unrolledLoopState.breakFixupCount = 0;
        }
    }

    override void visit(ImportStatement _is)
    {
        lastLoc = _is.loc;

        File(fromStringz(_is.loc.filename));
        Line(_is.loc.linnum);
        // can be skipped
        return ;
    }

    override void visit(AssertExp ae)
    {
        lastLoc = ae.loc;

        File(fromStringz(ae.loc.filename));
        Line(ae.loc.linnum);

        if (isBoolExp(ae.e1))
        {
            bailout("asserts on boolean expressions currently unsupported");
            return ;
        }

        auto lhs = genExpr(ae.e1, "AssertExp.e1");
        if (lhs.type.type == BCTypeEnum.i32 || lhs.type.type == BCTypeEnum.Ptr || lhs.type.type == BCTypeEnum.Struct
            || lhs.type.type == BCTypeEnum.Class)
        {
            if (!ae.msg)
            {
                const char* msg = ae.toChars();
                import core.stdc.string : strlen;

                auto len = strlen(msg);
                string errorMessage = cast(string) msg[0 .. len];
                Assert(lhs.i32, addError(ae.loc, errorMessage));
            }
            else
            {

                if (ae.msg.op != TOK.string_)
                {
                    BCValue errorMessage = genExpr(ae.msg);
                    Assert(lhs.i32, addErrorWithMessage(ae.loc, errorMessage));
                }
                else
                {
                    const(char)[] errorMessage = ae.msg.toString;
                    Assert(lhs.i32, addError(ae.loc, errorMessage));
                }
            }

        }
        else
        {
            bailout("Non integral expression in assert (should probably never happen) -- " ~ ae.toString());
            return ;
        }
    }

    override void visit(SwitchStatement ss)
    {
        lastLoc = ss.loc;

        File(fromStringz(ss.loc.filename));
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
                bailout("switching on undefined value " ~ ss.toString);
                return ;
            }

            bool stringSwitch = lhs.type.type == BCTypeEnum.string8;

            if (ss.cases.dim > beginCaseStatements.length)
                assert(0, "We will not have enough array space to store all cases for gotos");

            foreach (size_t i_, caseStmt; *(ss.cases))
            {
                uint i = cast(uint)i_;
                switchFixup = &switchFixupTable[switchFixupTableCount];
                caseStmt.index = i;
                // apperently I have to set the index myself;

                auto rhs = genExpr(caseStmt.exp);
                stringSwitch ? StringEq(BCValue.init, lhs, rhs) : Eq3(BCValue.init,
                    lhs, rhs);
                auto jump = beginCndJmp();
                if (caseStmt.statement)
                {
                    import dmd.blockexit;
                    auto blockExitResult = caseStmt.statement.blockExit(me, false);
                    bool blockReturns = !!(blockExitResult & (BE.any & ~BE.fallthru));
                    bool falltrough = !!(blockExitResult & BE.fallthru);

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

            //after we are done let's set those indexes back to zero
            //who knows what will happen if we don't?
            foreach (cs; *(ss.cases))
            {
                cs.index = 0;
            }
        }
    }

    override void visit(GotoCaseStatement gcs)
    {
        lastLoc = gcs.loc;

        File(fromStringz(gcs.loc.filename));
        Line(gcs.loc.linnum);
        with (switchState)
        {
            *switchFixup = SwitchFixupEntry(beginJmp(), gcs.cs.index + 1);
            switchFixupTableCount++;
        }
    }

    override void visit(GotoDefaultStatement gd)
    {
        lastLoc = gd.loc;

        File(fromStringz(gd.loc.filename));
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
                return ;
            }
        }

        unresolvedGotos[unresolvedGotoCount].ident = ident;
        unresolvedGotos[unresolvedGotoCount].jumpCount = 1;
        unresolvedGotos[unresolvedGotoCount++].jumps[0] = jmp;

    }

    override void visit(GotoStatement gs)
    {
        lastLoc = gs.loc;

        File(fromStringz(gs.loc.filename));
        Line(gs.loc.linnum);
        auto ident = cast(void*) gs.ident;

        if (auto labeledBlock = ident in labeledBlocks)
        {
            Jmp(labeledBlock.begin);
        }
        else
        {
            addUnresolvedGoto(ident, BCBlockJump(beginJmp(), BCBlockJumpTarget.Begin));
        }
    }

    override void visit(LabelStatement ls)
    {
        lastLoc = ls.loc;

        File(fromStringz(ls.loc.filename));
        Line(ls.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("LabelStatement %s", ls.toString);
        }

        if (cast(void*) ls.ident in labeledBlocks)
        {
            bailout("We already enountered a LabelStatement with this identifier");
            return ;
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
                // so who cares... In fact I suspect the branch would be more expensive :)
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
        lastLoc = cs.loc;

        File(fromStringz(cs.loc.filename));
        Line(cs.loc.linnum);
        if (cs.ident)
        {
            if (auto target = cast(void*) cs.ident in labeledBlocks)
            {
                Jmp(target.begin);
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
        lastLoc = bs.loc;

        File(fromStringz(bs.loc.filename));
        Line(bs.loc.linnum);
        if (bs.ident)
        {
            if (auto target = cast(void*) bs.ident in labeledBlocks)
            {
                Jmp(target.end);
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
        lastLoc = ce.loc;

        File(fromStringz(ce.loc.filename));
        Line(ce.loc.linnum);

        bool wrappingCallFn;
        if (!insideFunction)
        {
            // bailout("We cannot have calls outside of functions");
            // We are not inside a function body hence we are expected to return the result of this call.
            // For that to work we construct a function which will look like this { return fn(); }
            beginFunction(_sharedCtfeState.functionCount++);
            retval = genTemporary(toBCType(ce.type));
            insideFunction = true;
            wrappingCallFn = true;
        }
        BCValue thisPtr;
        BCValue fnValue;
        FuncDeclaration fd;
        bool isFunctionPtr;

        //NOTE it could also be Tdelegate


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
            assert((cast(TypeDelegate) ce.e1.type).nextOf.ty == Tfunction);
            tf = cast(TypeFunction) ((cast(TypeDelegate) ce.e1.type).nextOf);
        }
        else
        {
            bailout("CallExp.e1.type.ty expected to be Tfunction, but got: " ~ enumToString(cast(TY) ce.e1.type.ty));
            return ;
        }
        TypeDelegate td = cast (TypeDelegate) ce.e1.type;
        import dmd.asttypename;

        if (ce.e1.op == TOK.variable)
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
        else if (ce.e1.op == TOK.dotVariable)
        {
            Expression ethis;
            DotVarExp dve = cast(DotVarExp)ce.e1;

            // Calling a member function
            ethis = dve.e1;

            if (!dve.var || !dve.var.isFuncDeclaration())
            {
                bailout("no dve.var or it's not a funcDecl callExp -- " ~ dve.toString);
                return ;
            }
            fd = dve.var.isFuncDeclaration();
            thisPtr = genExpr(dve.e1);

            if (dve.e1.type.ty == Tclass && fd.isVirtualMethod())
            {
                isFunctionPtr = true;
                fnValue = genTemporary(i32Type);
                auto bcType = toBCType(dve.e1.type);

                addVirtualCall(bcType, fd);

                Comment("loadVtblPtr");

                auto vtblPtr = genTemporary(i32Type);
                // because of forward_referencing issues we need to assert
                // that we do indeed have a this pointer
                // what a pain
                Assert(thisPtr.i32, addError(lastLoc, "Calling virtual function on null class ... maybe forward-reference?"));
                Load32FromOffset(vtblPtr, thisPtr.i32, ClassMetaData.VtblOffset);
                Assert(vtblPtr.i32, addError(lastLoc, "vtblPointer null -- class " ~ dve.e1.type.toString() ~" was not constructed properly"));
                const vtblIndex = fd.vtblIndex;

                Comment("vtblLoad for vtblIdx: " ~ itos(vtblIndex) ~ " function: " ~ fd.toString());
                enum sizeofVtblEntry = 4;
                IndexedScaledLoad32(fnValue.i32, vtblPtr.i32, imm32(vtblIndex + 1), sizeofVtblEntry);
                Assert(fnValue.i32, addError(lastLoc, "function pointer null -- vtbl entry corrupt"));
                // bailout("A virtual call ... Oh No! -- " ~ ce.toString);
            }
        }
        // functionPtr
        else if (ce.e1.op == TOK.star)
        {
            isFunctionPtr = true;
            fnValue = genExpr(ce.e1);
        }
        // functionLiteral
        else if (ce.e1.op == TOK.function_)
        {
            //auto fnValue = genExpr(ce.e1);
            fd = (cast(FuncExp)ce.e1).fd;
        }

        enum DruntimeBultin
        {
            Invalid = 0,
            setArrayLength,
            nodeFromName,
        }

        static DruntimeBultin isDruntimeBuiltin(FuncDeclaration fd)
        {
            DruntimeBultin result = DruntimeBultin.Invalid;
            import dmd.id : Id;
            if (fd.ident == Id._d_arraysetlengthT)
            {
                result = DruntimeBultin.setArrayLength;
            }
            else
            {
                static if (__traits(compiles, { import dmd.reflect; } ))
                {
                   import dmd.reflect;

                    if (auto rKind = reflectKind(fd))
                    {
                        import dmd.dinterpret : ctfeGlobals;
                        if (rKind == REFLECT.nodeFromName)
                        {
                            return DruntimeBultin.nodeFromName;
                        }
                        else
                            assert(0, "Unknown reflection builtin");
                    }
                }
            }
            return result;
        }

        if (fd)
        {
            const drt_builtin = isDruntimeBuiltin(fd);
            final switch (drt_builtin) with (typeof(drt_builtin))
            {
                case setArrayLength :
                {
                    auto arrayExp = (*ce.arguments)[0];
                    auto newLengthExp = (*ce.arguments)[1];

                    auto array = genExpr(arrayExp, "ArrayExpansion Slice");
                    if (!array)
                    {
                        bailout("I don't have an array to load the length from :(");
                        return ;
                    }

                    if (array.type.type != BCTypeEnum.Slice && array.type.type != BCTypeEnum.string8)
                    {
                        bailout("can only assign to slices and not to " ~ enumToString(array.type.type));
                    }

                    BCValue newLength = genExpr(newLengthExp, "ArrayExpansion newLength");
                    expandSliceTo(array, newLength);
                    retval = newLength;
                    return ;
                }
                case nodeFromName : {
                    BCValue[] args;
                    args.length = ce.arguments.length; 
                    foreach(i, arg;*ce.arguments)
                    {
                        args[i] = genExpr(arg);
                        printf("arg: %s ... bcValue %s", arg.toChars(), args[i].toString().ptr);
                    }
                    auto val = genTemporary(toBCType(ce.type));
                    Call(val, imm32(uint.max - 1), args);
                    retval = val;
                    return ;
                }
                case Invalid : {} break; // just move on
            }
        }

        if (!isFunctionPtr)
        {
            if (!fd)
            {
                bailout("could not get funcDecl -- " ~ astTypeName(ce.e1) ~ " -- toK :" ~ enumToString(ce.e1.op) );
                return ;
            }

            int fnIdx = _sharedCtfeState.getFunctionIndex(fd);
            if (!fnIdx && cacheBC)
            {
                // FIXME deferring can only be done if we are NOT in a closure
                // if we get here the function was not already there.
                // allocate the next free function index, take note of the function
                // and move on as if we had compiled it :)
                // by deferring this we avoid a host of nasty issues!
                addUncompiledFunction(fd, &fnIdx);
            }
            if (!fnIdx)
            {
                bailout("We could not compile " ~ ce.toString);
                return ;
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
        uint nParameters = tf.parameterList.parameters ? cast(uint)tf.parameterList.parameters.dim : 0;

        if (ce.arguments.dim > nParameters)
        {
            nParameters = cast(uint) Parameter.dim(tf.parameterList.parameters);
        }

        assert(ce.arguments.dim <= nParameters);

        uint lastArgIdx = cast(uint)(ce.arguments.dim > nParameters ? ce.arguments.dim : nParameters);
        bc_args.length = lastArgIdx + !!(thisPtr) + (fd ? fd.isNested() : 0);

        foreach (i, arg; *ce.arguments)
        {
            bc_args[i] = genExpr(arg, "CallExpssion Argument");
            if (bc_args[i].vType == BCValueType.Unknown)
            {
                bailout(arg.toString ~ " did not evaluate to a valid argument");
                return ;
            }
            if (bc_args[i].type.type == BCTypeEnum.i64)
            {
                if (!is(BCGen) && !is(Print_BCGen))
                {
                    bailout(arg.toString ~ " cannot safely pass 64bit arguments yet");
                    return ;
                }
            }

            if (Parameter.getNth(tf.parameterList.parameters, i).storageClass & STC.ref_)
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

        if (thisPtr)
        {
            bc_args[lastArgIdx] = thisPtr;
        }

        if (fd ? fd.isNested() && me.closureVars.dim : false)
        {
            bc_args[lastArgIdx + !!thisPtr] = closureChain;
            // now we need to store back into the closure
            int i;
            foreach(cv, offset; closureVarOffsets)
            {
                auto closureptr_offset = gen.genLocal(i32Type, "closureptr_offset_" ~ itos(ce.loc.linnum) ~ itos(i++));
                // here the "gen." is needed although it should be found via
                // alias this
                //TODO investiage bug!
                auto vd = cast(VarDeclaration) cv;
                gen.Add3(closureptr_offset, closureChain, imm32(offset));
                BCValue var = getVariable(vd);
                //printf("Generating Store-Back for %s\n", vd.toChars()); //debugline
                var.heapRef = BCHeapRef(closureptr_offset);
                gen.Comment("Store local variable in closure_chain --  "~ vd.toString());
                StoreToHeapRef(var);
            }
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
                    bailout("can only handle " ~ itos(cast(int)calls.length) ~ " function-calls per topLevel evaluation");
                    return ;
                }
            }

            if (!fnValue)
            {
                bailout("Function could not be generated in: " ~ ce.toString);
                return ;
            }
            Comment("Calling " ~ ce.toString());
            Call(retval, fnValue, bc_args, ce.loc);
            uint arguments_dim = cast(uint) ce.arguments.dim;
            //FIXME figure out what we do in the case where we have more arguments than parameters
            //TEMPORARY: for now it seems to be enough to only iterate the min of args and params

            if (fd ? fd.isNested() && me.closureVars.dim : false)
            {
                bc_args[lastArgIdx + !!thisPtr] = closureChain;
                // now we need to load the the closure bak into our localsc
                auto closureptr_offset = genLocal(i32Type, "closureptr_offset");
                foreach(cv, offset; closureVarOffsets)
                {
                    gen.Comment("Closure Load Back");
                    // here the "gen." is needed although it should be found via
                    // alias this
                    //TODO investiage bug!
                    gen.Add3(closureptr_offset, closureChain, imm32(offset));
                    BCValue var = getVariable(cast(VarDeclaration) cv);
                    var.heapRef = BCHeapRef(closureptr_offset);
                    LoadFromHeapRef(var);
                }
            }

            foreach(size_t i, ref arg;bc_args)
            {
              if (arguments_dim > i && nParameters > i && Parameter.getNth(tf.parameterList.parameters, i).storageClass & STC.ref_)
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
                        bailout("could not generate origArg[" ~ itos(cast(uint)i) ~ "] for ref in: " ~ ce.toString);
                        return ;
                    }
                    origArg.heapRef = BCHeapRef(arg);
                    LoadFromHeapRef(origArg);
              }
            }

            import dmd.identifier;
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
        return ;

    }

    void addVirtualCall(BCType t, FuncDeclaration fd)
    {
        assert(t.type == BCTypeEnum.Class);
        assert(fd.isVirtualMethod);
        auto vtblIdx = fd.vtblIndex;
        assert(vtblIdx != -1);

        ClassDeclaration vtblRoot = _sharedCtfeState.classDeclTypePointers[t.typeIndex - 1];

        BCClass* bcClass = &_sharedCtfeState.classTypes[t.typeIndex - 1];

        bool seenIdx = false;

        foreach (uvi; bcClass.usedVtblIdxs)
        {
            if (uvi == vtblIdx)
                seenIdx = true;
        }

        if (!seenIdx)
            bcClass.usedVtblIdxs ~= vtblIdx;

        int fIdx = _sharedCtfeState.getFunctionIndex(fd);
        if (!fIdx)
        {
            addUncompiledFunction(fd, &fIdx, true);
        }
    }

    void dumpVtbls()
    {
        foreach(ci;0 .. _sharedCtfeState.classCount)
        {
            auto ct = _sharedCtfeState.classTypes[ci];
            auto cdtp = _sharedCtfeState.classDeclTypePointers[ci];
            printf("Vtbl for: %s (At: %d, parentAt: %d)\n", cdtp.toChars(), ct.vtblPtr, loadu32(&_sharedExecutionState.heap.heapData[ct.vtblPtr]));
            if (ct.vtblPtr) foreach(uvi;ct.usedVtblIdxs)
            {
                const parentVtblPtr = ct.vtblPtr;
                const offset = ct.vtblPtr + (uvi * 4) + 4;
                auto value = loadu32(&_sharedExecutionState.heap.heapData[offset]);
                if (_sharedCtfeState.functionCount >= value)
                {
                    auto fd = value
                        ? cast(FuncDeclaration)_sharedCtfeState.functions[value - 1].funcDecl
                        : null;

                    printf("    [%d] = %d (%s(%s))\n", uvi, value,
                        fd ? fd.toPrettyChars
                            : "unused vtbl slot",
                        fd && fd.parameters ? fd.parameters.toChars
                            : ""
                    );
                }
                else
                {
                    printf("    [%d] = %d (%s)\n", uvi, value, "Invalid function pointer".ptr);
                }
            }
        }
    }

    void buildVtbls()
    {
        foreach(ci;0 .. _sharedCtfeState.classCount)
        {
            auto ct = &_sharedCtfeState.classTypes[ci];
            auto cdtp = _sharedCtfeState.classDeclTypePointers[ci];
            static if (bailoutMessages)
            {
                // printf("Buidling vtbl for: %s\n", cdtp.toPrettyChars);
            }

            int maxIdx;
            uint[] vtbl = new uint[](16);
            vtbl.length = 16;

            if (ct.parentIdx)
            {
                const pct = &_sharedCtfeState.classTypes[ct.parentIdx - 1];
                assert(pct.vtblPtr, "the parent must have a vtbl ptr!");
                vtbl[0] = pct.vtblPtr;
            outerLoop: foreach(puvi;pct.usedVtblIdxs)
                {
                    foreach(uvi;ct.usedVtblIdxs)
                    {
                        if (puvi == uvi)
                            continue outerLoop;
                    }
                    ct.usedVtblIdxs ~= puvi;
                }
            }
            foreach(vti;ct.usedVtblIdxs)
            {
                if (vti >= maxIdx)
                {
                    maxIdx = vti  + 1;
                    if (maxIdx >= vtbl.length)
                    {
                        vtbl.length = maxIdx + 1;
                    }
                }
                auto vtblEntry = cdtp.vtbl[vti];
                auto fd = vtblEntry.isFuncDeclaration();
                assert(fd, "vtblEntry is no funcDecl ? -- " ~ vtblEntry.toString);
                auto fIdx = _sharedCtfeState.getFunctionIndex(fd);
                static if (bailoutMessages)
                {
                    // printf("\twriting entry #%d for: '%s' fIdx: %d\n", vti, fd.toPrettyChars, fIdx);
                }
                if (!fIdx)
                {
                    addUncompiledFunction(fd, &fIdx, true);
                }
                assert(fIdx);
                vtbl[vti + 1] = fIdx;
            }
            const vtblLength = maxIdx + 1;
            static if (bailoutMessages)
            {
                // printf("vtblLength: %d\n", vtblLength);
            }
            const vtblPtr = _sharedExecutionState.heap.heapSize;
            foreach(vti;0 .. vtblLength)
            {
                const offset = vtblPtr + (vti * 4);
                storeu32(&_sharedExecutionState.heap.heapData[offset], vtbl[vti]);
            }
            _sharedExecutionState.heap.heapSize += vtblLength * 4;
            ct.vtblPtr = vtblPtr;
        }
        compileUncompiledFunctions();
    }

    override void visit(ReturnStatement rs)
    {
        lastLoc = rs.loc;

        File(fromStringz(rs.loc.filename));
        Line(rs.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("ReturnStatement %s", rs.toString);
        }
        assert(!inReturnStatement);
        assert(!discardValue, "A returnStatement cannot be in discarding mode");

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
                    enum a = [c8, i8, u8, c16, i16, u16, c32, i32, u32, i64, u64, f23, f52, Slice, Array, Struct, string8, Function, Class, Null];
                    return cast(typeof(a[0])[a.length]) a;
                }
            } ();
            pragma(msg, typeof(acceptedReturnTypes));
            if (retval.type.type.anyOf(acceptedReturnTypes))
                Ret(retval);
            else
            {
                bailout(
                    "could not handle returnStatement with BCType " ~ enumToString(retval.type.type));
                return ;
            }
        }
        else
        {
            // rs.exp is null for  "return ;"
            // return ; is only legal when the return type is void
            // so we can return a bcNull without fearing consequences.

            Ret(bcNull);
        }

    }

    override void visit(CastExp ce)
    {
        //FIXME have this work with assignTo
        //

        lastLoc = ce.loc;

        File(fromStringz(ce.loc.filename));
        Line(ce.loc.linnum);
        //FIXME make this handle casts properly
        //e.g. do truncation and so on
        debug (ctfe)
        {
            import std.stdio;

            writeln("CastExp: ", ce.toString());
            writeln("FromType: ", ce.e1.type.toString);
            writeln("ToType: ", ce.to.toString);
            writeln("CastToBCType: ", toBCType(ce.to));
            writeln("CastFromBCType: ", toBCType(ce.e1.type));
        }

        auto toType = toBCType(ce.to);
        auto fromType = toBCType(ce.e1.type);

        retval = genExpr(ce.e1, "CastExp.e1");
        // for some reason Dynamic casts only see the baseClass
        // as toType ?
        if (toType.type != BCTypeEnum.Class && toType == fromType)
        {
            //newCTFE does not need to cast
        }
        else if (toType.type == BCTypeEnum.Ptr)
        {
            if (fromType.type == BCTypeEnum.Slice &&
                _sharedCtfeState.elementType(fromType) == _sharedCtfeState.elementType(toType))
            {
                // do nothing pointer have the same abi as slices :)
                // HACK FIXME this might not be actually the case
                retval.type = toType;
            }
            else
            {
                bailout("We cannot cast pointers");
                Assert(imm32(0), addError(ce.loc, "pointer cast not supported in ctfe"));
            }


            return ;
        }
        else if (fromType.type == BCTypeEnum.c32)
        {
            if (toType.type != BCTypeEnum.i32 && toType.type != BCTypeEnum.i64)
                bailout("CastExp unsupported: " ~ ce.toString);
        }
        else if (fromType.type == BCTypeEnum.i8 || fromType.type == BCTypeEnum.c8 || fromType.type == BCTypeEnum.u8)
        {
            // A "bitcast" is enough. All implementations are assumed to use 32/64bit registers.
            if (toType.type.anyOf([BCTypeEnum.i8, BCTypeEnum.c8, BCTypeEnum.i32, BCTypeEnum.u32, BCTypeEnum.c32, BCTypeEnum.i16, BCTypeEnum.i64, BCTypeEnum.u64]))
                retval.type = toType;
            else
            {
                bailout("Cannot do cast toType:" ~ enumToString(toType.type) ~ " -- "~ ce.toString);
                return ;
            }
        }
        else if (fromType.type == BCTypeEnum.f52 && toType.type == BCTypeEnum.f23)
        {
            const from = retval;
            retval = genTemporary(toType);
            F64ToF32(retval, from);
        }
        else if (fromType.type == BCTypeEnum.f23 && toType.type == BCTypeEnum.f52)
        {
            const from = retval;
            retval = genTemporary(toType);
            F32ToF64(retval, from);
        }
        else if (fromType.type == BCTypeEnum.f23 && (toType.type == BCTypeEnum.i32 || toType.type == BCTypeEnum.u32))
        {
                const from = retval;
                retval = genTemporary(toType);
                F32ToI(retval, from);
                And3(retval, retval, imm32(uint.max));
        }
        else if (fromType.type == BCTypeEnum.i32 || fromType.type == BCTypeEnum.i64 || fromType.type == BCTypeEnum.u32 || fromType.type == BCTypeEnum.u64)
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
            else if (toType.type == BCTypeEnum.i32 || toType.type == BCTypeEnum.u32)
            {
                auto from = retval;
                retval = genTemporary(toType);
                And3(retval, from, imm32(uint.max));
            }
            else if (toType.type == BCTypeEnum.i64) {} // nop
            else if (toType.type == BCTypeEnum.u64) {} // nop
            else if (toType.type.anyOf([BCTypeEnum.c8, BCTypeEnum.i8, BCTypeEnum.u8]))
            {
                And3(retval.i32, retval.i32, imm32(0xff));
            }
            else if (toType.type.anyOf([BCTypeEnum.c16, BCTypeEnum.i16, BCTypeEnum.u16]))
            {
                And3(retval.i32, retval.i32, imm32(0xffff));
            }
            else
            {
                bailout("Cast not implemented: " ~ ce.toString);
                return ;
            }
            retval.type = toType;
        }
        else if (fromType.type == BCTypeEnum.f52 && (toType.type == BCTypeEnum.u32 || toType.type == BCTypeEnum.i32))
        {
                const from = retval;
                retval = genTemporary(toType);
                F64ToI(retval, from);

        }
        else if ((fromType.type == BCTypeEnum.u64 || fromType.type == BCTypeEnum.u32) &&
            (toType.type == BCTypeEnum.u64 || toType.type == BCTypeEnum.u32))
        {
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
                == BCTypeEnum.u8)
        {
            // for the cast(ubyte[])string case
            // for now make an u8 slice
            retval.type = toType;
        }
        else if (toType.type == BCTypeEnum.string8
                && fromType.type == BCTypeEnum.Slice && fromType.typeIndex
                && _sharedCtfeState.sliceTypes[fromType.typeIndex - 1].elementType.type
                == BCTypeEnum.i8)
        {
            // for the cast(byte[])string case
            // for now make an u8 slice
            retval.type = _sharedCtfeState.sliceOf(BCType(BCTypeEnum.u8));
            //retval.type = toType;
        }
        else if (toType.type == BCTypeEnum.Class && fromType.type == BCTypeEnum.Class)
        {
            ClassDeclaration cdTo = _sharedCtfeState.classDeclTypePointers[toType.typeIndex - 1];
            ClassDeclaration cdFrom = _sharedCtfeState.classDeclTypePointers[fromType.typeIndex - 1]; 

            if (cdTo.isBaseOf(cdFrom, null))
            {
                // down cast we don't have to do anyting!
                retval.type = toType;
            }
            else
            {
                // A dynamic cast needs to call a function since we may don't know the vtbl ptrs yet
                Comment("-- DynamicCastBegin --");

                int castFnIdx = getDynamicCastIndex(toType);
                if (!castFnIdx)
                {
                    addDynamicCast(toType, &castFnIdx);
                }
                auto from = retval;
                retval = genLocal(toType, "DynamicCastResult" ~ itos(uniqueCounter++));
                Call(retval.i32, imm32(castFnIdx), [from]);

                Comment("-- DynamicCastEnd --");
            }
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
        Jmp(block.begin);
        auto after_jmp = genLabel();
        fixupBreak(oldBreakFixupCount, after_jmp);

    }

    override void visit(ExpStatement es)
    {
        lastLoc = es.loc;

        File(fromStringz(es.loc.filename));
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
        lastLoc = ds.loc;

        File(fromStringz(ds.loc.filename));
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
                return ;
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
        lastLoc = ws.loc;

        //Line(ws.loc.linnum);
        //File(fromStringz(ws.loc.filename));

        debug (ctfe)
        {
            import std.stdio;
            import dmd.asttypename;

            writefln("WithStatement %s", ws.toString);
            writefln("WithStatement.exp %s", ws.exp.toString);
            writefln("astTypeName(WithStatement.exp) %s", ws.exp.astTypeName);
            writefln("WithStatement.exp.op %s", ws.exp.op);
            if (ws.wthis) writefln("WithStatement.wthis %s", ws.wthis.toString);
        }
        if (!ws.wthis && ws.exp.op == TOK.type)
        {
            genBlock(ws._body);
            return ;
        }
        else
            bailout("We don't handle WithStatements (execpt with(Type))");
    }

    override void visit(Statement s)
    {
        lastLoc = s.loc;

        File(fromStringz(s.loc.filename));
        Line(s.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("Statement %s", s.toString);
        }
        import dmd.asttypename;
        bailout("Statement unsupported " ~ s.astTypeName ~ " :: " ~ s.toString);
    }

    override void visit(IfStatement fs)
    {
        lastLoc = fs.loc;

        File(fromStringz(fs.loc.filename));
        Line(fs.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("IfStatement %s", fs.toString);
        }
        import dmd.blockexit;

        if (fs.condition.is__ctfe == 1 || fs.condition.isBool(true))
        {
            if (fs.ifbody)
            {
                int be = 0;
                if (!(blockExitFlags & BlockExitFlags.in_condition))
                    be = blockExit(fs.ifbody, me, false);
                genBlock(fs.ifbody);
                // if the block exits with a return that means everything after is unreachable
                if (be == 4) blockExitFlags |= BlockExitFlags.unconditional_exit;
            }
            return ;
        }
        else if (fs.condition.is__ctfe == -1 || fs.condition.isBool(false))
        {
            if (fs.elsebody)
            {
                int be = 0;
                if (!(blockExitFlags & BlockExitFlags.in_condition))
                    be = blockExit(fs.elsebody, me, false);
                genBlock(fs.elsebody);
                // if the block exits with a return that means everything after is unreachable
                if (be == 4) blockExitFlags |= BlockExitFlags.unconditional_exit;
            }
            return ;
        }

        auto old = blockExitFlags;
        blockExitFlags |= BlockExitFlags.in_condition;
        scope(exit)
            blockExitFlags = old;

        uint oldFixupTableCount = fixupTableCount;
        bool boolExp = isBoolExp(fs.condition);

        if (boolExp)
        {
            boolres = genTemporary(i32Type);
        }

        auto cond = genExpr(fs.condition);

        if (!cond)
        {
            bailout("IfStatement: Could not generate condition" ~ fs.condition.toString);
            return ;
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
        lastLoc = ss.loc;

        File(fromStringz(ss.loc.filename));
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
        lastLoc = cs.loc;

        File(fromStringz(cs.loc.filename));
        Line(cs.loc.linnum);
        debug (ctfe)
        {
            import std.stdio;

            writefln("CompoundStatement %s", cs.toString);
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
                    if (blockExitFlags & BlockExitFlags.unconditional_exit)
                    {
                        blockExitFlags = 0;
                        break;
                    }
                }
            }
        }
        else
        {
            //TODO figure out if this is an invalid case.
            //bailout("No Statements in CompoundStatement");
            return ;
        }
    }
}
