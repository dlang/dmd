/*
TEST_OUTPUT:
---
fail_compilation/fail170.d(8): Error: variable fail170.foo.x final cannot be applied to variable, perhaps you meant const?
---
*/

void foo(final out int x) { }
