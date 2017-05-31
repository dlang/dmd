pragma (msg, (uint a) { a += add8ret3(a); return a;}(1));
uint add8ret3(ref uint a) {a += 8; return 3;}

pragma (msg, (uint outer) { uint inner = outer; inner += add8ret3(inner); return inner; }(1)); // will print 12 as expected.

/+
    Initialize();

    auto p1 = genParameter(BCType(BCTypeEnum.i32));//SP[4]
    beginFunction(0);
    auto tmp1 = genTemporary(BCType(BCTypeEnum.i32));//SP[8]
    Alloc(tmp1, BCValue(Imm32(4)));
    Store32(tmp1, p1);
    auto tmp2 = genTemporary(BCType(BCTypeEnum.i32));//SP[12]
    Call(tmp2, BCValue(Imm32(2)), [tmp1]);
    Load32(p1, tmp1);
    Add3(p1, p1, tmp2);
    Ret(p1);
    endFunction();


    auto p1_fn_1 = genParameter(BCType(BCTypeEnum.i32));//SP[4]
    auto tmp1_fn_1 = genTemporary(BCType(BCTypeEnum.i32));//SP[8]
    beginFunction(1);
    Load32(tmp1_fn_1, p1_fn_1);
    Add3(tmp1_fn_1, tmp1_fn_1, BCValue(Imm32(8)));
    Store32(p1_fn_1, tmp1_fn_1);
    Ret(BCValue(Imm32(3)));
    endFunction();

    Finalize();
+/
