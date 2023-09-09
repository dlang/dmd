/*
TEST_OUTPUT:
---
fail_compilation/ice11974.d(7): Error: `0` is not an lvalue and cannot be modified
---
*/
void main() {  0 = __LINE__ ^^ [ 0 ] ; }
