module ddmd.ctfe.bc_llvm_backend;

static immutable llvm_imports = q{
    import llvm.c.analysis;
    import llvm.c.core;
    import llvm.c.transforms.scalar;
    import llvm.c.executionEngine;
    import llvm.c.target;
};

static uint MegaBytes(uint size)
{
    return size * 1024 * 1024;
}

static if (!is(typeof(() { mixin(llvm_imports); })))
{
    pragma(msg, "SDCs LLVM Header are not avilable\nLLVM_Backend is not compiled");
}
else
    struct LLVM_BCGen
{

    import ddmd.ctfe.bc_common;
    import std.conv;

    //	string source;

    mixin(llvm_imports);

    bool sameLabel = true;
    auto sp = StackAddr(4);
    ushort temporaryCount;

    LLVMValueRef heap;

    LLVMValueRef heapTop;

    LLVMValueRef ccond; /// current condition;
    LLVMContextRef ctx;
    LLVMModuleRef mod;
    LLVMBuilderRef builder;

    LLVMValueRef fn;
    LLVMValueRef stack;

    BCType[64] parameterTypes;
    byte parameterCount;

    LLVMValueRef[1024] functions;
    uint functionCount;

    //bllockCount and blocks are function-LocalState,
    //this needs to be pushed on a stack if we are to allow nested function definitions

    LLVMBasicBlockRef[512] blocks;
    uint blockCount;
    char* error = null; // Used to retrieve messages from functions

    void Initialize()
    {
        LLVMInitializeX86TargetInfo();
        LLVMInitializeX86Target();
        LLVMInitializeX86TargetMC();
        LLVMInitializeX86AsmPrinter();
        LLVMLinkInMCJIT();

        functionCount = 0;

        mod = LLVMModuleCreateWithName("CTFE");
        heap = LLVMAddGlobal(mod, LLVMArrayType(LLVMInt32Type(), 2 ^^ 16), "heap");
        heapTop = LLVMAddGlobal(mod, LLVMInt32Type(), "heapTop");

        builder = LLVMCreateBuilder();
    }

    void Finalize()
    {
        LLVMDumpModule(mod);
        LLVMPassManagerRef pass = LLVMCreatePassManager();
        LLVMAddConstantPropagationPass(pass);
        LLVMAddInstructionCombiningPass(pass);
        LLVMAddPromoteMemoryToRegisterPass(pass);
        LLVMAddGVNPass(pass);
        LLVMAddCFGSimplificationPass(pass);
        LLVMRunPassManager(pass, mod);
        LLVMDisposeBuilder(builder);
    }

    void print()
    {
        LLVMDumpModule(mod);
        LLVMVerifyModule(mod, LLVMVerifierFailureAction.PrintMessage, &error);
        LLVMPassManagerRef pass = LLVMCreatePassManager();
        //LLVMAddTargetData(LLVMGetExecutionEngineTargetData(engine), pass);
        LLVMAddConstantPropagationPass(pass);
        LLVMAddInstructionCombiningPass(pass);
        // LLVMAddDemoteMemoryToRegisterPass(pass); // Demotes every possible value to memory
        LLVMAddPromoteMemoryToRegisterPass(pass);
        LLVMAddGVNPass(pass);
        LLVMAddCFGSimplificationPass(pass);
        LLVMRunPassManager(pass, mod);
        LLVMDumpModule(mod);
    }

    void newBlock()
    {
        blocks[blockCount] = LLVMAppendBasicBlock(fn, ("Block_" ~ to!string(blockCount)).ptr);
        /*        if (!LLVMGetBasicBlockTerminator(blocks[blockCount - 1]))
        {
            LLVMBuildBr(builder, blocks[blockCount]);
        } */
        LLVMPositionBuilderAtEnd(builder, blocks[blockCount++]);
    }

    LLVMValueRef toLLVMValueRef(BCValue v)
    {
        if (v.type.type == BCTypeEnum.Char)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.String)
            v = v.i32;
        else if (v.type.type == BCTypeEnum.Slice)
            v = v.i32;

        assert(v.type.type == BCTypeEnum.i32 || v.type.type == BCTypeEnum.i32Ptr
            || v.type.type == BCTypeEnum.i64,
            "i32 or i32Ptr expected not: " ~ to!string(v.type.type));

        if (v.type.type == BCTypeEnum.i32Ptr)
        {
            assert(v.vType == BCValueType.StackValue);
            auto addr1 = LLVMConstInt(LLVMInt32Type(), v.stackAddr, false);
            auto gep1 = LLVMBuildInBoundsGEP(builder, stack, &addr1, 1, "");
            auto load1 = LLVMBuildLoad(builder, gep1, "");
            return LLVMBuildGEP(builder, stack, &load1, 1, "");
        }
        else if (v.vType == BCValueType.StackValue)
        {
            return LLVMBuildLoad(builder, stackGEP(v), "");
        }
        else if (v.vType == BCValueType.Parameter)
        {
            return LLVMGetParam(fn, v.param - 1);
        }
        else if (v.vType == BCValueType.Immediate)
        {
            if (v.type.type == BCTypeEnum.i64)
            {
                return LLVMConstInt(LLVMInt32Type(), v.imm64, false);
            }
            else
            {
                return LLVMConstInt(LLVMInt32Type(), v.imm32, false);
            }
        }
        else
        {
            assert(0, "unsupported");
        }
    }

    uint beginFunction(uint fnn = 0)
    {
        LLVMTypeRef[] parameterTypes;

        foreach (_; 0 .. parameterCount)
        {
            parameterTypes ~= LLVMInt32Type();
        }

        fn = functions[functionCount] = LLVMAddFunction(mod, "",
            LLVMFunctionType(LLVMInt32Type(), parameterTypes.ptr,
            cast(uint) parameterTypes.length, 0));
        LLVMSetFunctionCallConv(fn, LLVMCallConv.C);
        //assert(blockCount == 0);
        blocks[blockCount] = LLVMAppendBasicBlock(fn, ("Block_" ~ to!string(blockCount)).ptr);
        assert(builder, "Me no have no builder. Have you called Initialize() man ?");
        LLVMPositionBuilderAtEnd(builder, blocks[blockCount++]);

        stack = LLVMBuildAlloca(builder, LLVMArrayType(LLVMInt32Type(), short.max),
            "");
        return (functionCount < functions.length) ? ++functionCount : 0;
    }

    void endFunction()
    {
        if (!LLVMGetFirstInstruction(blocks[blockCount - 1]))
        {
            LLVMBuildUnreachable(builder);
        }
        parameterCount = 0;
    }

    BCValue interpret(BCValue[] args, BCHeap* heapPtr)
    {
        import std.datetime;

        StopWatch sw;
        sw.start();
        scope (exit)
        {
            sw.stop();
            import std.stdio;

            writeln("Interpretation took ", sw.peek.usecs, " us");
        }
        LLVMVerifyModule(mod, LLVMVerifierFailureAction.AbortProcess, &error);
        LLVMDisposeMessage(error); // Handler == LLVMAbortProcessAction -> No need to check errors

        LLVMExecutionEngineRef engine;
        LLVMModuleProviderRef provider = LLVMCreateModuleProviderForExistingModule(mod);
        error = null;
        if (LLVMCreateJITCompilerForModule(&engine, mod, 2, &error) != 0)
        {
            import core.stdc.stdio, core.stdc.stdlib;

            fprintf(stderr, "%s\n", error);
            LLVMDisposeMessage(error);
            abort();
        }
        LLVMAddGlobalMapping(engine, heapTop, &heapPtr.heapSize);
        LLVMAddGlobalMapping(engine, heap, &heapPtr._heap[0]);
        //LLVMPassManagerRef pass = LLVMCreatePassManager();
        //LLVMAddTargetData(LLVMGetExecutionEngineTargetData(engine), pass);
        //      LLVMAddConstantPropagationPass(pass);
        //    LLVMAddInstructionCombiningPass(pass);
        //  LLVMAddDemoteMemoryToRegisterPass(pass); // Demotes every possible value to memory
        //    LLVMAddPromoteMemoryToRegisterPass(pass);
        //  LLVMAddGVNPass(pass);
        //LLVMAddCFGSimplificationPass(pass);
        //LLVMRunPassManager(pass, mod);

        LLVMGenericValueRef[] gv_args;
        foreach (arg; args)
        {
            gv_args ~= LLVMCreateGenericValueOfInt(LLVMInt32Type(), arg.imm32, true);
        }
        LLVMGenericValueRef exec_res = LLVMRunFunction(engine, fn,
            cast(uint) args.length, gv_args.ptr);
        auto res = cast(int) LLVMGenericValueToInt(exec_res, 1);
        auto ret = BCValue(Imm32(res));
        //LLVMDisposePassManager(pass);
        LLVMDisposeExecutionEngine(engine);
        return ret;
    }

    BCValue genTemporary(BCType bct)
    {
        auto tmp = BCValue(StackAddr(sp), bct, temporaryCount++);
        sp += align4(basicTypeSize(bct));
        return tmp;
    }

    BCValue genParameter(BCType bct)
    {
        auto p = BCValue(BCParameter(++parameterCount, bct, sp));
        sp += 4;
        return p;
    }

    BCAddr beginJmp()
    {
        assert(!LLVMGetBasicBlockTerminator(blocks[blockCount - 1]));
        BCAddr ret = BCAddr(blockCount - 1);
        newBlock();
        return ret;
    }

    void endJmp(BCAddr atIp, BCLabel target)
    {
        LLVMPositionBuilderAtEnd(builder, blocks[atIp]);
        if (atIp != target.addr)
        {
            LLVMBuildBr(builder, blocks[target.addr]);
        }
        else // SkipJumps to myself same as the interpreter backend;
        {
            debug(ctfe)
            {
                assert(0, "We should never jump to ourselfs");
            }
            LLVMBuildBr(builder, blocks[target.addr+1]);
        }
        LLVMPositionBuilderAtEnd(builder, blocks[blockCount - 1]);

    }

    void incSp()
    {
        sp += 4;
    }

    StackAddr currSp()
    {
        return sp;
    }

    BCLabel genLabel()
    {
        // If the block does not yet have an instruction there is no need for a new block;
        if (!LLVMGetLastInstruction(blocks[blockCount - 1]))
        {
            sameLabel = true;
        }

        if (!sameLabel)
        {
            sameLabel = true;
            bool needsBr = LLVMGetBasicBlockTerminator(blocks[blockCount - 1]) is null;
            newBlock();
            if (needsBr)
            {
                LLVMPositionBuilderAtEnd(builder, blocks[blockCount - 2]);
                LLVMBuildBr(builder, blocks[blockCount - 1]);
                LLVMPositionBuilderAtEnd(builder, blocks[blockCount - 1]);
            }
        }

        return BCLabel(BCAddr(blockCount - 1));

    }

    CndJmpBegin beginCndJmp(BCValue cond = BCValue.init, bool ifTrue = false)
    {
        if (!cond)
        {
            LLVMDumpModule(mod);
            assert(ccond !is null);
            cond.voidStar = cast(void*) ccond;
        }
        newBlock();
        return CndJmpBegin(BCAddr(blockCount - 2), cond, ifTrue);
    }

    void endCndJmp(CndJmpBegin jmp, BCLabel target)
    {
        sameLabel = false;
        LLVMValueRef cond;
        LLVMPositionBuilderAtEnd(builder, blocks[jmp.at]);
        if (!jmp.cond)
        {
            assert(jmp.cond.voidStar !is null);
            cond = (cast(LLVMValueRef)(jmp.cond.voidStar));
            assert(cond);
        }
        else
        {
            cond = LLVMBuildICmp(builder, LLVMIntPredicate.NE,
                toLLVMValueRef(jmp.cond), LLVMConstInt(LLVMInt32Type(), 0, false),
                "");
            assert(cond);
        }

        assert(cond);
        if (!blocks[jmp.at + 1])
        {
            import std.stdio;

            LLVMDumpModule(mod);
            writeln("BlockCount :", blockCount);
            assert(0);
        }

        assert(blocks[target.addr]);

        if (jmp.ifTrue)
        {
            LLVMBuildCondBr(builder, cond, blocks[target.addr], blocks[jmp.at + 1]);
        }
        else
        {
            LLVMBuildCondBr(builder, cond, blocks[jmp.at + 1], blocks[target.addr]);
        }
        LLVMPositionBuilderAtEnd(builder, blocks[blockCount - 1]);
    }

    void genJump(BCLabel target)
    {
        sameLabel = false;
        LLVMBuildBr(builder, blocks[target.addr]);
    }

    void emitFlg(BCValue lhs)
    {
        sameLabel = false;
        StoreStack(LLVMBuildIntCast(builder, ccond, LLVMInt32Type(), ""), lhs);
    }

    void AssertError(BCValue val, BCValue msg);
    void Alloc(BCValue heapPtr, BCValue size)
    {
        auto hTop = LLVMBuildLoad(builder, heapTop, "");
        auto newTop = LLVMBuildAdd(builder, hTop, toLLVMValueRef(size), "");
        LLVMBuildStore(builder, newTop, heapTop);
    }

    void Not(BCValue _result, BCValue val)
    {
        sameLabel = false;
    }

    void Set(BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        assert(lhs.vType == BCValueType.StackValue
            || lhs.vType == BCValueType.Parameter, to!string(lhs.vType));
        StoreStack(toLLVMValueRef(rhs), lhs);
    }

    LLVMValueRef stackGEP(BCValue v)
    {
        auto addr1 = [
            LLVMConstInt(LLVMInt32Type(), 0, false),
            LLVMConstInt(LLVMInt32Type(), v.stackAddr, false)
        ];
        return LLVMBuildInBoundsGEP(builder, stack, addr1.ptr, 2, "");
    }

    LLVMValueRef heapTopGEP()
    {
        auto addr1 = LLVMConstInt(LLVMInt32Type(), 0, false);
        return LLVMBuildInBoundsGEP(builder, heapTop, &addr1, 1, "");
    }

    LLVMValueRef heapGEP(BCValue v)
    {
        auto addr1 = [LLVMConstInt(LLVMInt32Type(), 0, false), toLLVMValueRef(v)];
        return LLVMBuildInBoundsGEP(builder, heap, addr1.ptr, 2, "");
    }

    LLVMValueRef heapPtr(BCValue v)
    {
        //auto addr1 = [LLVMConstInt(LLVMInt32Type(), 0, false), toLLVMValueRef(v)];
        auto ptrAsInt = LLVMBuildPtrToInt(builder, heap,
            LLVMInt32Type(), "");
        auto addResult = LLVMBuildAdd(builder, ptrAsInt, toLLVMValueRef(v), "");
        return LLVMBuildIntToPtr(builder, addResult,
            LLVMTypeOf(heap), "");


    }

    void StoreStack(BCValue value, BCValue addr)
    {
        StoreStack(toLLVMValueRef(value), addr);
    }

    void StoreStack(LLVMValueRef value, BCValue addr)
    {
        sameLabel = false;
        LLVMBuildStore(builder, value, stackGEP(addr));
    }

    void Lt3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        ccond = LLVMBuildICmp(builder, LLVMIntPredicate.SLT,
            toLLVMValueRef(lhs), toLLVMValueRef(rhs), "");
        if (_result)
        {
            emitFlg(_result);
        }
    }

    void Gt3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        ccond = LLVMBuildICmp(builder, LLVMIntPredicate.SGT,
            toLLVMValueRef(lhs), toLLVMValueRef(rhs), "");
        if (_result)
        {
            emitFlg(_result);
        }
    }

    void Le3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        ccond = LLVMBuildICmp(builder, LLVMIntPredicate.SLE,
            toLLVMValueRef(lhs), toLLVMValueRef(rhs), "");
        if (_result)
        {
            emitFlg(_result);
        }
    }

    void Ge3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        ccond = LLVMBuildICmp(builder, LLVMIntPredicate.SGE,
            toLLVMValueRef(lhs), toLLVMValueRef(rhs), "");
        if (_result)
        {
            emitFlg(_result);
        }
    }

    void Eq3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        ccond = LLVMBuildICmp(builder, LLVMIntPredicate.EQ,
            toLLVMValueRef(lhs), toLLVMValueRef(rhs), "");

        if (_result)
        {
            emitFlg(_result);
        }
    }

    void Neq3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        ccond = LLVMBuildICmp(builder, LLVMIntPredicate.NE,
            toLLVMValueRef(lhs), toLLVMValueRef(rhs), "");
        if (_result)
        {
            emitFlg(_result);
        }
    }

    void Add3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        StoreStack(LLVMBuildAdd(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);

    }

    void Sub3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        StoreStack(LLVMBuildSub(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void Mul3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;

        StoreStack(LLVMBuildMul(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void Div3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        StoreStack(LLVMBuildSDiv(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void And3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;

        StoreStack(LLVMBuildAnd(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void Or3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;
        StoreStack(LLVMBuildOr(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs), ""),
            _result);
    }

    void Xor3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;

        StoreStack(LLVMBuildXor(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void Lsh3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;

        StoreStack(LLVMBuildShl(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void Rsh3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;

        StoreStack(LLVMBuildLShr(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void Mod3(BCValue _result, BCValue lhs, BCValue rhs)
    {
        sameLabel = false;

        StoreStack(LLVMBuildURem(builder, toLLVMValueRef(lhs), toLLVMValueRef(rhs),
            ""), _result);
    }

    void Byte3(BCValue _result, BCValue word, BCValue idx)
    {
        sameLabel = false;
        import ddmd.ctfe.bc_macro : Byte3Macro;

        Byte3Macro(&this, _result, word, idx);
    }
    import ddmd.globals : Loc;
    void Call(BCValue _result, BCValue fn, BCValue[] args, Loc l = Loc.init);
    void Load32(BCValue _to, BCValue from)
    {
        sameLabel = false;

        StoreStack(LLVMBuildLoad(builder, heapGEP(from), ""), _to);
    }

    void Store32(BCValue _to, BCValue value)
    {
        sameLabel = false;
        LLVMBuildStore(builder, toLLVMValueRef(value), heapGEP(_to)); 
    }

    void Ret(BCValue val)
    {
        sameLabel = false;
        LLVMBuildRet(builder, toLLVMValueRef(val));
        newBlock();
    }

    void Cat(BCValue _result, const BCValue lhs, const BCValue rhs, const uint size)
    {
        sameLabel = false;
    }

    void Halt(BCValue message)
    {
        if (!message)
            LLVMBuildUnreachable(builder);
    }

    static void test()
    {
        import ddmd.ctfe.bc_common;
        import std.datetime;

        StopWatch sw;
        import ddmd.ctfe.bc;

        LLVM_BCGen gen;
        //sw.reset();
        sw.start();
        /+
        with (gen)
        {
            Initialize();
            auto p1 = genParameter(BCType(BCTypeEnum.Char)); //SP[4]
            beginFunction();
            auto jmp1 = beginJmp();
            auto label1 = genLabel();
            incSp();
            Set(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(Imm32(0)));
            Eq3(BCValue.init, p1, BCValue(Imm32(97)));
            auto cndJmp1 = beginCndJmp();
            auto label2 = genLabel();
            Ret(BCValue(Imm32(5)));
            auto label3 = genLabel();
            endCndJmp(cndJmp1, label3);
            Eq3(BCValue.init, p1, BCValue(Imm32(98)));
            auto cndJmp2 = beginCndJmp();
            auto label4 = genLabel();
            Ret(BCValue(Imm32(2)));
            auto label5 = genLabel();
            endCndJmp(cndJmp2, label5);
            Eq3(BCValue.init, p1, BCValue(Imm32(100)));
            auto cndJmp3 = beginCndJmp();
            auto label6 = genLabel();
            auto jmp2 = beginJmp();
            auto label7 = genLabel();
            endCndJmp(cndJmp3, label7);
            Eq3(BCValue.init, p1, BCValue(Imm32(99)));
            auto cndJmp4 = beginCndJmp();
            auto label8 = genLabel();
            auto tmp1 = genTemporary(BCType(BCTypeEnum.i32)); //SP[12]
            Sub3(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(Imm32(1)));
            auto tmp2 = genTemporary(BCType(BCTypeEnum.i32)); //SP[16]
            Add3(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(Imm32(1)));
            auto tmp3 = genTemporary(BCType(BCTypeEnum.i32)); //SP[20]
            Add3(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(Imm32(1)));
            auto jmp3 = beginJmp();
            auto label9 = genLabel();
            endCndJmp(cndJmp4, label9);
            Eq3(BCValue.init, p1, BCValue(Imm32(102)));
            auto cndJmp5 = beginCndJmp();
            auto label10 = genLabel();
            auto jmp4 = beginJmp();
            auto label11 = genLabel();
            endCndJmp(cndJmp5, label11);
            Eq3(BCValue.init, p1, BCValue(Imm32(101)));
            auto cndJmp6 = beginCndJmp();
            auto label12 = genLabel();
            auto jmp5 = beginJmp();
            auto label13 = genLabel();
            endCndJmp(cndJmp6, label13);
            auto label14 = genLabel();
            Ret(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)));
            auto label15 = genLabel();
            endJmp(jmp2, label4);
            endJmp(jmp3, label14);
            endJmp(jmp4, label4);
            endJmp(jmp5, label15);
            Ret(BCValue(Imm32(16)));
            auto label16 = genLabel();
            endJmp(jmp1, label16);
            auto jmp6 = beginJmp();
            endJmp(jmp6, label1);
            endFunction();
            Finalize();
//            LLVMDumpModule(mod);
            +/
        with (gen)
        {
            Initialize();
            beginFunction();
            incSp();
            Set(BCValue(StackAddr(4), BCType(BCTypeEnum.i32)), BCValue(Imm32(0)));
            //currSp();//SP[8]
            incSp();
            Set(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(Imm32(0)));
            //currSp();//SP[12]
            incSp();
            Set(BCValue(StackAddr(12), BCType(BCTypeEnum.i32)), BCValue(Imm32(64)));
            auto label2 = genLabel();
            Lt3(BCValue.init, BCValue(StackAddr(8), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(12), BCType(BCTypeEnum.i32)));
            auto cndJmp1 = beginCndJmp();
            auto label3 = genLabel(); //currSp();//SP[16]
            incSp();
            Set(BCValue(StackAddr(16), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(8), BCType(BCTypeEnum.i32))); //currSp();//SP[20]
            incSp();
            auto tmp1 = genTemporary(BCType(BCTypeEnum.i32)); //SP[24]
            Set(tmp1.i32, BCValue(Imm32(0)));
            Set(BCValue(StackAddr(20), BCType(BCTypeEnum.i32)), tmp1); //currSp();//SP[28]
            incSp();
            Set(BCValue(StackAddr(28), BCType(BCTypeEnum.i32)), BCValue(Imm32(0)));
            auto label4 = genLabel();
            auto tmp2 = genTemporary(BCType(BCTypeEnum.i32)); //SP[32]
            Load32(tmp2, BCValue(StackAddr(20), BCType(BCTypeEnum.i32)));
            Lt3(BCValue.init, BCValue(StackAddr(28), BCType(BCTypeEnum.i32)), tmp2);
            auto cndJmp2 = beginCndJmp();
            auto label5 = genLabel();
            //currSp();//SP[36]
            incSp();
            auto tmp3 = genTemporary(BCType(BCTypeEnum.i32)); //SP[40]
            Add3(tmp3, BCValue(StackAddr(20), BCType(BCTypeEnum.i32)), BCValue(Imm32(1)));
            auto tmp4 = genTemporary(BCType(BCTypeEnum.i32)); //SP[44]
            auto tmp5 = genTemporary(BCType(BCTypeEnum.i32)); //SP[48]
            Mod3(tmp5, BCValue(StackAddr(28), BCType(BCTypeEnum.i32)), BCValue(Imm32(4)));
            Div3(tmp4, BCValue(StackAddr(28), BCType(BCTypeEnum.i32)), BCValue(Imm32(4)));
            Add3(tmp3, tmp3, tmp4);
            Load32(tmp2, tmp3);
            Byte3(tmp2, tmp2, tmp5);
            Set(BCValue(StackAddr(36), BCType(BCTypeEnum.i32)), tmp2);
            Add3(BCValue(StackAddr(4), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(4), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(36), BCType(BCTypeEnum.i32)));
            auto label6 = genLabel();
            Add3(BCValue(StackAddr(28), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(28), BCType(BCTypeEnum.i32)), BCValue(Imm32(1)));
            auto label7 = genLabel();
            auto jmp2 = beginJmp();
            endJmp(jmp2, label4);
            auto label8 = genLabel();
            endCndJmp(cndJmp2, label8);
            auto label9 = genLabel();
            Add3(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)),
                BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(Imm32(1)));
            auto label10 = genLabel();
            auto jmp3 = beginJmp();
            endJmp(jmp3, label2);
            auto label11 = genLabel();
            endCndJmp(cndJmp1, label11);
            Ret(BCValue(StackAddr(4), BCType(BCTypeEnum.i32)));
            endFunction();
            Finalize();
            LLVMDumpModule(mod);
            import std.stdio;

            StopWatch r;
            r.start();

            assert(interpret([], ({
                BCHeap* h1 = new BCHeap();
                h1.pushString("This is the world we live in.".ptr,
                    cast(uint) "This is the World we live in.".length);
                return h1;
            }())) == BCValue(Imm32(166784)));
            r.stop();
            writeln(r.peek.usecs, " us");
        }
    }

}
