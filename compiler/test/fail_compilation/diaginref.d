/*
REQUIRED_ARGS: -preview=in
TEST_OUTPUT:
---
fail_compilation/diaginref.d(15): Error: attribute `ref` is redundant with previously-applied `in`
void foo1(in ref string) {}
             ^
fail_compilation/diaginref.d(17): Error: attribute `in` cannot be added after `ref`: remove `ref`
void foo3(T)(ref in T v, string) {}
                 ^
---
 */

void foo(in string) {}
void foo1(in ref string) {}
void foo2(T)(in T v, string) {}
void foo3(T)(ref in T v, string) {}
