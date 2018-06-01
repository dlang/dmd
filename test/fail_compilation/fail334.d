/*
TEST_OUTPUT:
---
fail_compilation/fail334.d(15): Error: setter property can only have one parameter
fail_compilation/fail334.d(16): Error: setter property can only have one parameter
fail_compilation/fail334.d(17): Error: setter property can only have one parameter
fail_compilation/fail334.d(19): Error: getter properties must not return void
fail_compilation/fail334.d(26): Error: setter property can only have one or two parameters
fail_compilation/fail334.d(27): Error: getter properties must not return void
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

@property void set(int[]...) {}
@property void get() {}

