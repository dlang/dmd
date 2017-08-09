static immutable test_iota_range_string = q{
    Initialize();

    auto p1 = genParameter(BCType(BCTypeEnum.i32));//SP[4]
    beginFunction(0);//testThisCall
//currSp();//SP[8]
    incSp();
    Set(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(Imm32(0)));
//currSp();//SP[12]
    incSp();
    Call(BCValue(StackAddr(12), BCType(BCTypeEnum.Struct, 1)), BCValue(Imm32(2)), [p1]);
    auto label1 = genLabel();
    auto tmp1 = genTemporary(BCType(BCTypeEnum.i32));//SP[16]
    auto tmp2 = genTemporary(BCType(BCTypeEnum.i32));//SP[20]
    Call(tmp2, BCValue(Imm32(3)), [BCValue(StackAddr(12), BCType(BCTypeEnum.Struct, 1))]);
    Eq3(tmp1, tmp2, BCValue(Imm32(0)));
    auto cndJmp1 = beginCndJmp(tmp1);
    auto label2 = genLabel();
//currSp();//SP[24]
    incSp();
    Call(BCValue(StackAddr(24), BCType(BCTypeEnum.i32)), BCValue(Imm32(4)), [BCValue(StackAddr(12), BCType(BCTypeEnum.Struct, 1))]);
    Add3(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(StackAddr(8), BCType(BCTypeEnum.i32)), BCValue(StackAddr(24), BCType(BCTypeEnum.i32)));
    auto label3 = genLabel();
    auto tmp3 = genTemporary(BCType(BCTypeEnum.Void));//SP[28]
    Call(tmp3, BCValue(Imm32(5)), [BCValue(StackAddr(12), BCType(BCTypeEnum.Struct, 1))]);
    genJump(label1);
    auto label4 = genLabel();
    endCndJmp(cndJmp1, label4);
    Ret(BCValue(StackAddr(8), BCType(BCTypeEnum.i32)));
    endFunction();


    auto p1_fn_1 = genParameter(BCType(BCTypeEnum.i32));//SP[4]
    beginFunction(1);//Iota
    auto tmp1_fn_1 = genTemporary(BCType(BCTypeEnum.i32));//SP[8]
    Alloc(tmp1_fn_1, BCValue(Imm32(12)));
    auto tmp2_fn_1 = genTemporary(BCType(BCTypeEnum.i32));//SP[12]
    Add3(tmp2_fn_1, tmp1_fn_1, BCValue(Imm32(0)));
    Assert(tmp2_fn_1, Imm32(1)/*Error*/);
    Store32(tmp2_fn_1, BCValue(Imm32(0)));
    Add3(tmp2_fn_1, tmp1_fn_1, BCValue(Imm32(4)));
    Assert(tmp2_fn_1, Imm32(2)/*Error*/);
    Store32(tmp2_fn_1, BCValue(Imm32(0)));
    Add3(tmp2_fn_1, tmp1_fn_1, BCValue(Imm32(8)));
    Assert(tmp2_fn_1, Imm32(3)/*Error*/);
    Store32(tmp2_fn_1, BCValue(Imm32(0)));
    auto tmp3_fn_1 = genTemporary(BCType(BCTypeEnum.Struct, 1));//SP[16]
    Call(tmp3_fn_1, BCValue(Imm32(6)), [p1_fn_1, BCValue(Imm32(0)), BCValue(Imm32(1)), tmp1_fn_1]);
    Ret(tmp3_fn_1);
    endFunction();


    auto p1_fn_2 = genParameter(BCType(BCTypeEnum.Struct, 1));//SP[4]
    beginFunction(2);//empty
    Assert(p1_fn_2, Imm32(4)/*Error*/);
    auto tmp1_fn_2 = genTemporary(BCType(BCTypeEnum.i32));//SP[8]
    auto tmp2_fn_2 = genTemporary(BCType(BCTypeEnum.i32));//SP[12]
    auto tmp3_fn_2 = genTemporary(BCType(BCTypeEnum.i32));//SP[16]
    Add3(tmp3_fn_2, p1_fn_2, BCValue(Imm32(0)));
    Assert(tmp3_fn_2, Imm32(5)/*Error*/);
    Load32(tmp2_fn_2, tmp3_fn_2);
    auto tmp4_fn_2 = genTemporary(BCType(BCTypeEnum.i32));//SP[20]
    auto tmp5_fn_2 = genTemporary(BCType(BCTypeEnum.i32));//SP[24]
    Add3(tmp5_fn_2, p1_fn_2, BCValue(Imm32(4)));
    Assert(tmp5_fn_2, Imm32(6)/*Error*/);
    Load32(tmp4_fn_2, tmp5_fn_2);
    Gt3(tmp1_fn_2, tmp2_fn_2, tmp4_fn_2);
    Ret(tmp1_fn_2);
    endFunction();


    auto p1_fn_3 = genParameter(BCType(BCTypeEnum.Struct, 1));//SP[4]
    beginFunction(3);//front
    Assert(p1_fn_3, Imm32(7)/*Error*/);
    auto tmp1_fn_3 = genTemporary(BCType(BCTypeEnum.i32));//SP[8]
    auto tmp2_fn_3 = genTemporary(BCType(BCTypeEnum.i32));//SP[12]
    Add3(tmp2_fn_3, p1_fn_3, BCValue(Imm32(0)));
    Assert(tmp2_fn_3, Imm32(8)/*Error*/);
    Load32(tmp1_fn_3, tmp2_fn_3);
    Ret(tmp1_fn_3);
    endFunction();


    auto p1_fn_4 = genParameter(BCType(BCTypeEnum.Struct, 1));//SP[4]
    beginFunction(4);//popFront
    Assert(p1_fn_4, Imm32(9)/*Error*/);
    auto tmp1_fn_4 = genTemporary(BCType(BCTypeEnum.i32));//SP[8]
    auto tmp2_fn_4 = genTemporary(BCType(BCTypeEnum.i32));//SP[12]
    Add3(tmp2_fn_4, p1_fn_4, BCValue(Imm32(0)));
    Assert(tmp2_fn_4, Imm32(10)/*Error*/);
    Load32(tmp1_fn_4, tmp2_fn_4);
    auto tmp3_fn_4 = genTemporary(BCType(BCTypeEnum.i32));//SP[16]
    auto tmp4_fn_4 = genTemporary(BCType(BCTypeEnum.i32));//SP[20]
    Add3(tmp4_fn_4, p1_fn_4, BCValue(Imm32(8)));
    Assert(tmp4_fn_4, Imm32(11)/*Error*/);
    Load32(tmp3_fn_4, tmp4_fn_4);
    Add3(tmp1_fn_4, tmp1_fn_4, tmp3_fn_4);
    Assert(tmp2_fn_4, Imm32(12)/*Error*/);
    Store32(tmp2_fn_4, tmp1_fn_4);
    Ret(BCValue(Imm32(0/*null*/)));
    Ret(BCValue(Imm32(0/*null*/)));
    endFunction();


    auto p1_fn_5 = genParameter(BCType(BCTypeEnum.i32));//SP[4]
    auto p2_fn_5 = genParameter(BCType(BCTypeEnum.i32));//SP[8]
    auto p3_fn_5 = genParameter(BCType(BCTypeEnum.i32));//SP[12]
    auto p4_fn_5 = genParameter(BCType(BCTypeEnum.Struct, 1));//SP[16]
    beginFunction(5);//this
    auto tmp1_fn_5 = genTemporary(BCType(BCTypeEnum.i32));//SP[20]
    Neq3(tmp1_fn_5, p3_fn_5, BCValue(Imm32(0)));
    Assert(tmp1_fn_5, Imm32(13)/*Error*/);
    auto tmp2_fn_5 = genTemporary(BCType(BCTypeEnum.i32));//SP[24]
    Add3(tmp2_fn_5, p4_fn_5, BCValue(Imm32(8)));
    Assert(tmp2_fn_5, Imm32(14)/*Error*/);
    Store32(tmp2_fn_5, p3_fn_5);
    auto tmp3_fn_5 = genTemporary(BCType(BCTypeEnum.i32));//SP[28]
    Add3(tmp3_fn_5, p4_fn_5, BCValue(Imm32(0)));
    Assert(tmp3_fn_5, Imm32(15)/*Error*/);
    Store32(tmp3_fn_5, p2_fn_5);
    auto tmp4_fn_5 = genTemporary(BCType(BCTypeEnum.i32));//SP[32]
    Add3(tmp4_fn_5, p4_fn_5, BCValue(Imm32(4)));
    Assert(tmp4_fn_5, Imm32(16)/*Error*/);
    Store32(tmp4_fn_5, p1_fn_5);
    Ret(p4_fn_5);
    endFunction();

    Finalize();

};

