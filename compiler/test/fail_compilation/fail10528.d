/*
EXTRA_FILES: imports/a10528.d
TEST_OUTPUT:
---
fail_compilation/fail10528.d(48): Error: undefined identifier `a`
    auto a1 = a;
              ^
fail_compilation/fail10528.d(49): Error: undefined identifier `a` in module `a10528`
    auto a2 = imports.a10528.a;
                            ^
fail_compilation/fail10528.d(51): Error: undefined identifier `b`
    auto b1 = b;
              ^
fail_compilation/fail10528.d(52): Error: undefined identifier `b` in module `a10528`
    auto b2 = imports.a10528.b;
                            ^
fail_compilation/fail10528.d(54): Error: no property `c` for type `a10528.S`
    auto c1 = S.c;
              ^
fail_compilation/imports/a10528.d(4):        struct `S` defined here
struct S { private enum string c = "qwerty"; }
^
fail_compilation/fail10528.d(55): Error: no property `c` for type `a10528.S`
    with (S) auto c2 = c;
                       ^
fail_compilation/imports/a10528.d(4):        struct `S` defined here
struct S { private enum string c = "qwerty"; }
^
fail_compilation/fail10528.d(57): Error: no property `d` for type `a10528.C`
    auto d1 = C.d;
              ^
fail_compilation/imports/a10528.d(5):        class `C` defined here
class  C { private enum string d = "qwerty"; }
^
fail_compilation/fail10528.d(58): Error: no property `d` for type `a10528.C`
    with (C) auto d2 = d;
                       ^
fail_compilation/imports/a10528.d(5):        class `C` defined here
class  C { private enum string d = "qwerty"; }
^
---
*/

import imports.a10528;

void main()
{
    auto a1 = a;
    auto a2 = imports.a10528.a;

    auto b1 = b;
    auto b2 = imports.a10528.b;

    auto c1 = S.c;
    with (S) auto c2 = c;

    auto d1 = C.d;
    with (C) auto d2 = d;
}
