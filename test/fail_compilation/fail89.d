/*
TEST_OUTPUT:
---
fail_compilation/fail89.d(10): Error: circular reference to 'a'
fail_compilation/fail89.d(9):        while evaluating b.init
---
*/

const int a = b;
const int b = .a;
