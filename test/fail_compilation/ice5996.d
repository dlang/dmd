/*
TEST_OUTPUT:
---
fail_compilation/ice5996.d(9): Error: undefined identifier anyOldGarbage
fail_compilation/ice5996.d(12): Error: CTFE failed because of previous errors in bug5996
---
*/
auto bug5996() {
    if (anyOldGarbage) {}
    return 2;
}
enum uint h5996 = bug5996();
