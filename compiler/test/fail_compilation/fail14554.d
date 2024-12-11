// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail14554.d(32): Error: `fail14554.issue14554_1.foo` called with argument types `(int)` matches both:
fail_compilation/fail14554.d(21):     `fail14554.issue14554_1.foo!bool.foo(int j)`
and:
fail_compilation/fail14554.d(22):     `fail14554.issue14554_1.foo!bool.foo(int j)`
     issue14554_1.foo!bool(1);
                          ^
fail_compilation/fail14554.d(33): Error: `fail14554.issue14554_2.foo` called with argument types `(int)` matches both:
fail_compilation/fail14554.d(26):     `fail14554.issue14554_2.foo!bool.foo(int j)`
and:
fail_compilation/fail14554.d(27):     `fail14554.issue14554_2.foo!bool.foo(int j)`
     issue14554_2.foo!bool(1);
                          ^
---
*/
struct issue14554_1 {
     void foo(T)(int j) {}
     static void foo(T)(int j) {}
}

struct issue14554_2 {
     static void foo(T)(int j) {}
     void foo(T)(int j) {}
}

void test14554()
{
     issue14554_1.foo!bool(1);
     issue14554_2.foo!bool(1);
}
