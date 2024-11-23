/*
TEST_OUTPUT:
---
fail_compilation/fail296.d(12): Error: can only `*` a pointer, not a `int`
void main(){ *1; }
             ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=3117
// dmd crash by *1
void main(){ *1; }
