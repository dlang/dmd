module ddmd.ctfe.bc_macro;

import ddmd.ctfe.bc_common;

void Byte3Macro(BCGen)(BCGen* gen, BCValue _result, BCValue word, BCValue idx)
{
    with(gen) {
    Eq3(BCValue.init, idx, BCValue(Imm32(0)));
    auto cndJmp1 = beginCndJmp();
    auto tmp1 = genTemporary(BCType(BCTypeEnum.i32));//SP[12]
    And3(_result, word, BCValue(Imm32(255)));
    auto label3 = genLabel();
    endCndJmp(cndJmp1, label3);
    Eq3(BCValue.init, idx, BCValue(Imm32(1)));
    auto cndJmp2 = beginCndJmp();
    And3(tmp1, word, BCValue(Imm32(65280)));
    Rsh3(_result, tmp1, BCValue(Imm32(8)));
    auto label5 = genLabel();
    endCndJmp(cndJmp2, label5);
    Eq3(BCValue.init, idx, BCValue(Imm32(2)));
    auto cndJmp3 = beginCndJmp();
    And3(tmp1, word, BCValue(Imm32(16711680)));
    Rsh3(_result, tmp1, BCValue(Imm32(16)));
    auto label7 = genLabel();
    endCndJmp(cndJmp3, label7);
    Eq3(BCValue.init, idx, BCValue(Imm32(3)));
    auto cndJmp4 = beginCndJmp();
    And3(tmp1, word, BCValue(Imm32(4278190080)));
    Rsh3(_result, tmp1, BCValue(Imm32(24)));
    auto label9 = genLabel();
    endCndJmp(cndJmp4, label9);
    //Assert(Error);
    }
}

void StringEq3Macro(BCGen)(BCGen* gen, BCValue _result, BCValue lhs, BCValue rhs)
{
     with(gen) {
        auto lhsLength = genTemporary(i32Type);
        auto rhsLength = genTemporary(i32Type);
        Load32(lhsLength, lhs.i32);
        Load32(rhsLength, rhs.i32);
        Eq3(_result, lhsLength, rhsLength);
        auto length_equals_jmp = beginCndJmp(_result);

        auto lhsPtr = genTemporary(i32Type);
        auto rhsPtr = genTemporary(i32Type);
        Add3(lhsPtr, lhs.i32, bcOne);
        Add3(rhsPtr, rhs.i32, bcOne);
        // The prevoius add jump over the length
        {
            auto Lcompare_loop = genLabel();

            Eq3(BCValue.init, lhsLength, bcZero);
            auto endLoopJmp = beginCndJmp();
            Sub3(lhsLength, lhsLength, bcOne);
            BCValue lhsElem = genTemporary(i32Type);
            BCValue rhsElem = genTemporary(i32Type);
            Load32(lhsElem, lhsPtr); /* this translates to result = *lhs++ == *rhs++ */
            Load32(rhsElem, rhsPtr);
            Add3(lhsPtr, lhsPtr, bcOne);
            Add3(rhsPtr, rhsPtr, bcOne);
            Eq3(_result, lhsElem, rhsElem);
            auto jmp_to_cmpr = beginCndJmp(_result, false);
            auto Lafter_cmp_loop = genLabel();
            endCndJmp(endLoopJmp, Lafter_cmp_loop);
            endCndJmp(jmp_to_cmpr, Lcompare_loop);
        }
        endCndJmp(length_equals_jmp, genLabel());
    }
}
