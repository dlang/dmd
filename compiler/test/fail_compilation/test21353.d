/*
EXTRA_FILES: imports/imp21353.d
TEST_OUTPUT:
---
fail_compilation/test21353.d(38): Error: no property `A` for type `imports.imp21353.B`
    B.A;
    ^
fail_compilation/imports/imp21353.d(5):        struct `B` defined here
struct B { import imports.imp21353 : A; }
^
fail_compilation/test21353.d(39): Error: no property `A` for type `imports.imp21353.B`
    with (B) { A(0); }
               ^
fail_compilation/imports/imp21353.d(5):        struct `B` defined here
struct B { import imports.imp21353 : A; }
^
fail_compilation/test21353.d(40): Error: no property `A` for type `imports.imp21353.B`
    with (B()) { A(0); } // fixed
                 ^
fail_compilation/imports/imp21353.d(5):        struct `B` defined here
struct B { import imports.imp21353 : A; }
^
fail_compilation/test21353.d(42): Error: undefined identifier `P` in module `imports.imp21353`
    imports.imp21353.P();
                    ^
fail_compilation/test21353.d(43): Error: undefined identifier `P` in module `imports.imp21353`
    with (imports.imp21353) { P(); } // fixed
                              ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=21353

import imports.imp21353;

void main()
{
    B.A;
    with (B) { A(0); }
    with (B()) { A(0); } // fixed

    imports.imp21353.P();
    with (imports.imp21353) { P(); } // fixed
}
