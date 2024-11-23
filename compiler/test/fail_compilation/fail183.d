/*
TEST_OUTPUT:
---
fail_compilation/fail183.d(37): Error: attribute `const` is redundant with previously-applied `in`
void f1(in const int x) {}
           ^
fail_compilation/fail183.d(38): Error: attribute `scope` cannot be applied with `in`, use `-preview=in` instead
void f2(in scope int x) {}
           ^
fail_compilation/fail183.d(39): Error: attribute `const` is redundant with previously-applied `in`
void f3(in const scope int x) {}
           ^
fail_compilation/fail183.d(39): Error: attribute `scope` cannot be applied with `in`, use `-preview=in` instead
void f3(in const scope int x) {}
                 ^
fail_compilation/fail183.d(40): Error: attribute `scope` cannot be applied with `in`, use `-preview=in` instead
void f4(in scope const int x) {}
           ^
fail_compilation/fail183.d(40): Error: attribute `const` is redundant with previously-applied `in`
void f4(in scope const int x) {}
                 ^
fail_compilation/fail183.d(42): Error: attribute `in` cannot be added after `const`: remove `const`
void f5(const in int x) {}
              ^
fail_compilation/fail183.d(43): Error: attribute `in` cannot be added after `scope`: remove `scope` and use `-preview=in`
void f6(scope in int x) {}
              ^
fail_compilation/fail183.d(44): Error: attribute `in` cannot be added after `const`: remove `const`
void f7(const scope in int x) {}
                    ^
fail_compilation/fail183.d(45): Error: attribute `in` cannot be added after `const`: remove `const`
void f8(scope const in int x) {}
                    ^
---
*/

void f1(in const int x) {}
void f2(in scope int x) {}
void f3(in const scope int x) {}
void f4(in scope const int x) {}

void f5(const in int x) {}
void f6(scope in int x) {}
void f7(const scope in int x) {}
void f8(scope const in int x) {}
