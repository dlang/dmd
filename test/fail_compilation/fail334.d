// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail334.d(16): Deprecation: setter property can only have one parameter
fail_compilation/fail334.d(17): Deprecation: setter property can only have one parameter
fail_compilation/fail334.d(18): Deprecation: setter property can only have one parameter
fail_compilation/fail334.d(20): Deprecation: getter properties must not return void
fail_compilation/fail334.d(28): Deprecation: setter property can only have one or two parameters
fail_compilation/fail334.d(29): Deprecation: getter properties must not return void
---
*/

struct S
{
    @property int foo(int a, int b, int c) { return 1; }
    @property void set(int, int) {}
    @property void set(...) {}
    @property void set(int) {} // OK
    @property void get() {}
}

// OK
@property ufcs_set(Object obj, int val) {}
@property void set(int) {}
@property ref void get() {}

@property void set(int[]...) {}
@property void get() {}

