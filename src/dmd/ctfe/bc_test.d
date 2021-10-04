module dmd.ctfe.bc_test;

/// All my bc-tests
/// A Backend passing this can be considered a working CTFE-Backend for the code the new engine can execute

bool test(BCGenT)()
{

    import dmd.ctfe.bc_common;

    static immutable testArithFn = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        auto one = BCValue(Imm32(1));

        auto two = BCValue(Imm32(2));
        auto sixteen = BCValue(Imm32(16));
        auto four = BCValue(Imm32(4));

        gen.beginFunction();
        auto result = gen.genTemporary(BCType(BCTypeEnum.i32));
        gen.Mul3(result, two, sixteen); // 2*16 == 32
        gen.Div3(result, result, four); //32 / 4 == 8
        gen.Sub3(result, result, one); // 8 - 1 == 7
        gen.Ret(result);
        gen.endFunction();

        return gen;
    });
    pragma(msg, BCGenT.stringof);
    pragma(msg, typeof(testArithFn));
    static assert(testArithFn([], null) == BCValue(Imm32(7)));

    static immutable testBCFn = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {
            auto p1 = genParameter(BCType(BCTypeEnum.i32));

            beginFunction();
            Eq3(BCValue.init, p1, BCValue(Imm32(16)));
            auto cndJmp = beginCndJmp();
            Ret(BCValue(Imm32(16)));

            auto target = genLabel();

            auto result = genTemporary(BCType(BCTypeEnum.i32));

            Mul3(result, p1, BCValue(Imm32(4)));
            Div3(result, result, BCValue(Imm32(2)));

            Ret(result);

            endCndJmp(cndJmp, target);
            endFunction();
        }
        return gen;
    });

    static assert(testBCFn([BCValue(Imm32(12))], null) == BCValue(Imm32(24)));
    static assert(testBCFn([BCValue(Imm32(16))], null) == BCValue(Imm32(16)));

    static immutable testLtFn = BCGenFunction!(BCGenT, () {
        BCGenT gen;

        with (gen)
        {
            auto p1 = genParameter(BCType(BCTypeEnum.i32)); //first parameter gets pushed on here
            auto p2 = genParameter(BCType(BCTypeEnum.i32)); //the second goes here
            beginFunction();

            BCValue result = genTemporary(BCType(BCTypeEnum.i32));
            auto eval_label = genLabel();

            Lt3(BCValue.init, p1, p2);
            auto jnt = beginCndJmp();
            Set(result, BCValue(Imm32(1)));
            auto toReturn = beginJmp();
            auto ifFalse = genLabel();
            Set(result, (BCValue(Imm32(0))));
            endCndJmp(jnt, ifFalse);
            endJmp(toReturn, genLabel());
            Ret(result);
            endFunction();

        }

        return (gen);
    });

    static assert(testLtFn([BCValue(Imm32(21)), BCValue(Imm32(25))], null) == bcOne);
    static assert(testLtFn([BCValue(Imm32(27)), BCValue(Imm32(25))], null) != bcOne);
    static assert(testLtFn([BCValue(Imm32(25)), BCValue(Imm32(25))], null) != bcOne);

    static immutable testSwitchFn = BCGenFunction!(BCGenT, () {
        BCGenT gen;

        with (gen)
        {
            auto p1 = genParameter(BCType(BCTypeEnum.c8)); //SP[4]
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
        }

        return gen;
    });

    static assert(testSwitchFn([BCValue(Imm32('a'))], null) == BCValue(Imm32(5)));
    static assert(testSwitchFn([BCValue(Imm32('f'))], null) == BCValue(Imm32(2)));
    static assert(testSwitchFn([BCValue(Imm32(101))], null) == BCValue(Imm32(16)));
    static assert(testSwitchFn([BCValue(Imm32('d'))], null) == BCValue(Imm32(2)));

    static immutable testOrOr = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {
            auto p1 = genParameter(BCType(BCTypeEnum.i32)); //SP[4]
            auto p2 = genParameter(BCType(BCTypeEnum.i32)); //SP[8]
            beginFunction();
            auto jmp1 = beginJmp();
            auto label1 = genLabel();
            auto tmp1 = genTemporary(BCType(BCTypeEnum.i32 /*i1*/ )); //SP[12]
            auto tmp2 = genTemporary(BCType(BCTypeEnum.i32 /*i1*/ )); //SP[16]

            Eq3(tmp2, p1, BCValue(Imm32(5)));
            auto cndJmp1 = beginCndJmp(tmp2, true);
            auto tmp3 = genTemporary(BCType(BCTypeEnum.i32 /*i1*/ )); //SP[20]
            Eq3(tmp3, p2, BCValue(Imm32(6)));
            auto cndJmp2 = beginCndJmp(tmp3, true);
            auto label2 = genLabel();
            auto tmp4 = genTemporary(BCType(BCTypeEnum.i32 /*i1*/ )); //SP[24]
            Eq3(tmp4, p1, BCValue(Imm32(2)));
            Ret(tmp4);
            auto label3 = genLabel();
            Ret(BCValue(Imm32(1)));
            auto label4 = genLabel();
            endCndJmp(cndJmp1, label3);
            endCndJmp(cndJmp2, label3);
            auto label5 = genLabel();
            endJmp(jmp1, label5);
            auto jmp2 = beginJmp();
            endJmp(jmp2, label1);
            endFunction();
        }

        return gen;
    });

    static immutable testCndJmp = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {

            beginFunction();
            auto p1 = genTemporary(BCType(BCTypeEnum.i32)); //SP[4]
            auto label1 = genLabel();
            Add3(p1, p1, BCValue(Imm32(1)));
            auto tmp1 = genTemporary(BCType(BCTypeEnum.i32)); //SP[8]
            Lt3(tmp1, p1, BCValue(Imm32(3)));
            auto cndJmp1 = beginCndJmp(tmp1, true);
            endCndJmp(cndJmp1, label1);
            Ret(p1);
            endFunction();
        }
        return gen;
    });
    static assert(testCndJmp([], null) == BCValue(Imm32(3)));

    static immutable testEcho = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {

            Initialize();

            auto p1 = genParameter(BCType(BCTypeEnum.i32)); //SP[4]
            beginFunction(0);
            Ret(p1);
            endFunction();

            Finalize();
        }
        return gen;
    });

    static assert(testEcho([imm32(20)], null) == BCValue(Imm32(20)));

    static immutable testCmpInst = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {
            Initialize();

            beginFunction(0);//testCmpAssignment
                //auto v_1_fn_2 = genLocal(BCType(BCTypeEnum.i32), "v");//SP[12]
                auto v_1_fn_2 = genTemporary(BCType(BCTypeEnum.i32));//SP[12]
                Set(v_1_fn_2, BCValue(Imm32(4)));
                auto result_2_fn_2 = genLocal(BCType(BCTypeEnum.i32), "result");//SP[16]
                Eq3(result_2_fn_2, v_1_fn_2, BCValue(Imm32(4)));
                Ret(result_2_fn_2);
            endFunction();

            Finalize();
        }
        return gen;
    });

    static assert(testCmpInst([], null) == BCValue(Imm32(1)));


    static immutable testLoad64 = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {
            Initialize();
            scope (exit) Finalize();
            {
                beginFunction(0);

                auto t64 = genLocal(BCType(BCTypeEnum.i64), "t64");
                auto mem = genLocal(BCType(BCTypeEnum.i32), "mem");
                auto mem4 = genLocal(BCType(BCTypeEnum.i32), "mem4");

                Alloc(mem, imm32(8));
                Add3(mem4, mem, imm32(4));
                Store32(mem4, imm32(0x13371337));
                Store32(mem, imm32(0xDEADBEEF));
                Load64(t64, mem);
                Ret(t64);

                endFunction();
            }
        }
        return gen;
    });

    static assert(() {
        BCHeap heap; return testLoad64([], &heap);
    }().imm64.imm64 == 0x13371337DEADBEEF);

    static immutable testStore64 = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {
            Initialize();
            scope (exit) Finalize();
            {
                beginFunction(0);

                auto t64 = genLocal(BCType(BCTypeEnum.i64), "t64");
                auto t64_2 = genLocal(BCType(BCTypeEnum.i64), "t64_2");
                auto mem = genLocal(BCType(BCTypeEnum.i32), "mem");
                auto mem4 = genLocal(BCType(BCTypeEnum.i32), "mem4");

                Alloc(mem, imm32(8));
                Set(t64, imm32(0x13371337));
                Lsh3(t64, t64, imm32(32));
                Or3(t64, t64, imm32(0xDEADBEEF));
                Store64(mem, t64);
                Load64(t64_2, mem);
                Ret(t64_2);

                endFunction();
            }
        }
        return gen;
    });

    static assert(() {
        BCHeap heap; return testStore64([], &heap);
    }().imm64.imm64 == 0x13371337DEADBEEF);

    static immutable testPassthrough64 = BCGenFunction!(BCGenT, () {
        BCGenT gen;
        with (gen)
        {
            Initialize();

            beginFunction(0);//__lambda3
                auto tmp1 = genTemporary(BCType(BCTypeEnum.i64));//SP[4]
                Call(tmp1, BCValue(Imm32(2)), [BCValue(Imm64(4294967295 | (4294967295 << 32)))]);
                auto tmp2 = genTemporary(BCType(BCTypeEnum.i64));//SP[12]
                Call(tmp2, BCValue(Imm32(2)), [tmp1]);
                Ret(tmp1);
            endFunction();

            auto l_1_fn_1 = genParameter(BCType(BCTypeEnum.i64));//SP[4]
            beginFunction(1);//echo
                Ret(l_1_fn_1);
            endFunction();

            Finalize();
        }
        return gen;

    });

    pragma(msg, () {
        BCHeap heap; return testPassthrough64([], &heap);
    }()/*.imm64.imm64 == ulong.max*/);

    return true;
}
