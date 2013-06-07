// REQUIRED_ARGS: -unittest

/*
TEST_OUTPUT:
---
fail_compilation/fail7848.d(17): Error: pure function 'fail7848.__unittestL15_1' cannot call impure function 'fail7848.func'
fail_compilation/fail7848.d(17): Error: safe function 'fail7848.__unittestL15_1' cannot call system function 'fail7848.func'
fail_compilation/fail7848.d(17): Error: func is not nothrow
fail_compilation/fail7848.d(15): Error: function fail7848.__unittestL15_1 '__unittestL15_1' is nothrow yet may throw
---
*/

void func() {}

@safe pure nothrow unittest
{
    func();
}
