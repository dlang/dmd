/*
TEST_OUTPUT:
---
fail_compilation/test8751.d(9): Error: undefined identifier `Bar`
Bar foo3(ref const int x) pure {
    ^
---
*/
Bar foo3(ref const int x) pure {
    return y => x > y; // error
}
