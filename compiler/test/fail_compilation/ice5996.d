/*
TEST_OUTPUT:
---
fail_compilation/ice5996.d(10): Error: undefined identifier `anyOldGarbage`
    if (anyOldGarbage) {}
        ^
---
*/
auto bug5996() {
    if (anyOldGarbage) {}
    return 2;
}
enum uint h5996 = bug5996();
