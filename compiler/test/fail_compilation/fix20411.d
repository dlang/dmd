/*
TEST_OUTPUT:
---
fail_compilation/fix20411.d(9): Error: undefined identifier `AlmostSimilar`
---
*/

// https://github.com/dlang/dmd/issues/20411
const almostSimilar = AlmostSimilar;
