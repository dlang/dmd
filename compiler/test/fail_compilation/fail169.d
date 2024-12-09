/*
TEST_OUTPUT:
---
fail_compilation/fail169.d(10): Error: cannot have `const out` parameter of type `const(int)`
void foo(const out int x) { }
     ^
---
*/

void foo(const out int x) { }
