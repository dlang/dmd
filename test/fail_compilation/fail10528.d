/*
TEST_OUTPUT:
---
fail_compilation/fail10528.d(5): Error: module fail10528 variable a10528.a is private
fail_compilation/fail10528.d(5): Deprecation: a10528.a is not visible from module fail10528
fail_compilation/fail10528.d(6): Error: a10528.a is not visible from module fail10528
fail_compilation/fail10528.d(8): Error: module fail10528 enum member a10528.b is private
fail_compilation/fail10528.d(8): Deprecation: a10528.b is not visible from module fail10528
fail_compilation/fail10528.d(9): Error: a10528.b is not visible from module fail10528
fail_compilation/fail10528.d(11): Deprecation: a10528.S.c is not visible from module fail10528
fail_compilation/fail10528.d(11): Error: variable a10528.S.c is not accessible from module fail10528
fail_compilation/fail10528.d(12): Error: variable a10528.S.c is not accessible from module fail10528
fail_compilation/fail10528.d(14): Deprecation: a10528.C.d is not visible from module fail10528
fail_compilation/fail10528.d(14): Error: variable a10528.C.d is not accessible from module fail10528
fail_compilation/fail10528.d(15): Error: variable a10528.C.d is not accessible from module fail10528
---
*/

#line 1
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
