/*
TEST_OUTPUT:
---
fail_compilation/ice11626.d(10): Error: undefined identifier `Bar`
void foo(const ref Bar) {}
     ^
---
*/

void foo(const ref Bar) {}
