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
