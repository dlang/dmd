/*
TEST_OUTPUT:
---
fail_compilation/fail10528.d(23): Error: undefined identifier `a`, did you mean variable `a`?
fail_compilation/fail10528.d(24): Error: `a10528.a` is not visible from module `fail10528`
fail_compilation/fail10528.d(24): Error: undefined identifier `a` in module `a10528`, did you mean variable `a`?
fail_compilation/fail10528.d(26): Error: undefined identifier `b`, did you mean enum member `b`?
fail_compilation/fail10528.d(27): Error: `a10528.b` is not visible from module `fail10528`
fail_compilation/fail10528.d(27): Error: undefined identifier `b` in module `a10528`, did you mean enum member `b`?
fail_compilation/fail10528.d(29): Error: `a10528.S.c` is not visible from module `fail10528`
fail_compilation/fail10528.d(29): Error: no property `c` for type `S`, did you mean `a10528.S.c`?
fail_compilation/fail10528.d(30): Error: variable `a10528.S.c` is not accessible from module `fail10528`
fail_compilation/fail10528.d(32): Error: `a10528.C.d` is not visible from module `fail10528`
fail_compilation/fail10528.d(32): Error: no property `d` for type `a10528.C`, did you mean `a10528.C.d`?
fail_compilation/fail10528.d(33): Error: variable `a10528.C.d` is not accessible from module `fail10528`
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
