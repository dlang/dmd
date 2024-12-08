/*
EXTRA_FILES: imports/diag10089a.d imports/diag10089b.d
TEST_OUTPUT:
---
fail_compilation/diag10089.d(20): Error: undefined identifier `chunks` in package `imports`
    imports.chunks("abcdef", 2);
           ^
fail_compilation/diag10089.d(22): Error: template `Foo()` does not have property `chunks`
    Foo.chunks("abcdef", 2);
       ^
---
*/

import imports.diag10089a, imports.diag10089b;

template Foo() {}

void main()
{
    imports.chunks("abcdef", 2);

    Foo.chunks("abcdef", 2);
}
