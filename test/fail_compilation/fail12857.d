/*
TEST_OUTPUT:
---
fail_compilation/fail12857.d(15): Error: function fail12857.foo.f3 cannot annotate @system inside @safe function foo
fail_compilation/fail12857.d(17): Error: function fail12857.foo.f4!().f4 cannot annotate @system inside @safe function foo
fail_compilation/fail12857.d(18): Error: template instance fail12857.foo.f4!() error instantiating
fail_compilation/fail12857.d(20): Error: safe function 'fail12857.foo.f5' cannot call system function 'fail12857.systemFunc'
fail_compilation/fail12857.d(22): Error: safe function 'fail12857.foo.f6!().f6' cannot call system function 'fail12857.systemFunc'
fail_compilation/fail12857.d(23): Error: template instance fail12857.foo.f6!() error instantiating
---
*/

void foo() @safe
{
    void f3() @system {}    // error

    void f4()() @system {}  // error
    alias x4 = f4!();

    void f5() { systemFunc(); }     // error

    void f6()() { systemFunc(); }   // error
    alias x6 = f6!();
}

void systemFunc() @system {}
