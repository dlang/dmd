/*
TEST_OUTPUT:
---
fail_compilation/fail198.d(10): Error: template instance `test!42` template `test` is not defined
int x = test!(42);
        ^
---
*/

int x = test!(42);
