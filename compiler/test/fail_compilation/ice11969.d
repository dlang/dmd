/*
TEST_OUTPUT:
---
fail_compilation/ice11969.d(15): Error: undefined identifier `index`
void test1() { mixin ([index]); }
                       ^
fail_compilation/ice11969.d(16): Error: undefined identifier `cond`
void test2() { mixin (assert(cond)); }
                             ^
fail_compilation/ice11969.d(17): Error: undefined identifier `msg`
void test3() { mixin (assert(0, msg)); }
                                ^
---
*/
void test1() { mixin ([index]); }
void test2() { mixin (assert(cond)); }
void test3() { mixin (assert(0, msg)); }
