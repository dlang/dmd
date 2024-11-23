/*
TEST_OUTPUT:
---
fail_compilation/ice11974.d(9): Error: cannot modify constant `0`
void main() {  0 = __LINE__ ^^ [ 0 ] ; }
               ^
---
*/
void main() {  0 = __LINE__ ^^ [ 0 ] ; }
