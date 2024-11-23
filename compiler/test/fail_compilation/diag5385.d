/*
EXTRA_FILES: imports/fail5385.d
TEST_OUTPUT:
---
fail_compilation/diag5385.d(60): Error: no property `privX` for type `imports.fail5385.C`
    C.privX = 1;
    ^
fail_compilation/imports/fail5385.d(3):        class `C` defined here
class C
^
fail_compilation/diag5385.d(61): Error: no property `packX` for type `imports.fail5385.C`
    C.packX = 1;
    ^
fail_compilation/imports/fail5385.d(3):        class `C` defined here
class C
^
fail_compilation/diag5385.d(62): Error: no property `privX2` for type `imports.fail5385.C`
    C.privX2 = 1;
    ^
fail_compilation/imports/fail5385.d(3):        class `C` defined here
class C
^
fail_compilation/diag5385.d(63): Error: no property `packX2` for type `imports.fail5385.C`
    C.packX2 = 1;
    ^
fail_compilation/imports/fail5385.d(3):        class `C` defined here
class C
^
fail_compilation/diag5385.d(64): Error: no property `privX` for type `imports.fail5385.S`
    S.privX = 1;
    ^
fail_compilation/imports/fail5385.d(11):        struct `S` defined here
struct S
^
fail_compilation/diag5385.d(65): Error: no property `packX` for type `imports.fail5385.S`
    S.packX = 1;
    ^
fail_compilation/imports/fail5385.d(11):        struct `S` defined here
struct S
^
fail_compilation/diag5385.d(66): Error: no property `privX2` for type `imports.fail5385.S`
    S.privX2 = 1;
    ^
fail_compilation/imports/fail5385.d(11):        struct `S` defined here
struct S
^
fail_compilation/diag5385.d(67): Error: no property `packX2` for type `imports.fail5385.S`
    S.packX2 = 1;
    ^
fail_compilation/imports/fail5385.d(11):        struct `S` defined here
struct S
^
---
*/

import imports.fail5385;

void main()
{
    C.privX = 1;
    C.packX = 1;
    C.privX2 = 1;
    C.packX2 = 1;
    S.privX = 1;
    S.packX = 1;
    S.privX2 = 1;
    S.packX2 = 1;
}
