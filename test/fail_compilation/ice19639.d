/*
TEST_OUTPUT:
---
fail_compilation/ice19639.d(2): Error: cannot cast expression "" of type string to char[64]
because of different sizes
---
*/
enum EMPTY_STRING = "\0"[0..0];
void main() { char[64] buf = EMPTY_STRING; }
