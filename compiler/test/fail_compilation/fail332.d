/*
TEST_OUTPUT:
---
fail_compilation/fail332.d(84): Error: function `foo` is not callable using argument types `()`
    foo();
       ^
fail_compilation/fail332.d(84):        missing argument for parameter #1: `int __param_0`
fail_compilation/fail332.d(79):        `fail332.foo(int __param_0, ...)` declared here
void foo(int, ...) {}
     ^
fail_compilation/fail332.d(85): Error: function `foo` is not callable using argument types `(typeof(null))`
    foo(null);
       ^
fail_compilation/fail332.d(85):        cannot pass argument `null` of type `typeof(null)` to parameter `int __param_0`
fail_compilation/fail332.d(79):        `fail332.foo(int __param_0, ...)` declared here
void foo(int, ...) {}
     ^
fail_compilation/fail332.d(87): Error: function `baz` is not callable using argument types `(string)`
    baz("");
       ^
fail_compilation/fail332.d(87):        cannot pass argument `""` of type `string` to parameter `int[] __param_0...`
fail_compilation/fail332.d(80):        `fail332.baz(int[] __param_0...)` declared here
void baz(int[]...) {}
     ^
fail_compilation/fail332.d(88): Error: function `baz` is not callable using argument types `(int, typeof(null))`
    baz(3, null);
       ^
fail_compilation/fail332.d(88):        cannot pass argument `null` of type `typeof(null)` to parameter `int[] __param_0...`
fail_compilation/fail332.d(80):        `fail332.baz(int[] __param_0...)` declared here
void baz(int[]...) {}
     ^
fail_compilation/fail332.d(95): Error: function `bar` is not callable using argument types `()`
    bar();
       ^
fail_compilation/fail332.d(95):        missing argument for parameter #1: `Object`
fail_compilation/fail332.d(91):        `fail332.bar(Object, int[2]...)` declared here
void bar(Object, int[2]...);
     ^
fail_compilation/fail332.d(96): Error: function `bar` is not callable using argument types `(int)`
    bar(4);
       ^
fail_compilation/fail332.d(96):        cannot pass argument `4` of type `int` to parameter `Object`
fail_compilation/fail332.d(91):        `fail332.bar(Object, int[2]...)` declared here
void bar(Object, int[2]...);
     ^
fail_compilation/fail332.d(97): Error: function `bar` is not callable using argument types `(typeof(null))`
    bar(null);
       ^
fail_compilation/fail332.d(97):        expected 2 variadic argument(s), not 0
fail_compilation/fail332.d(91):        `fail332.bar(Object, int[2]...)` declared here
void bar(Object, int[2]...);
     ^
fail_compilation/fail332.d(98): Error: function `bar` is not callable using argument types `(typeof(null), int)`
    bar(null, 2);
       ^
fail_compilation/fail332.d(98):        expected 2 variadic argument(s), not 1
fail_compilation/fail332.d(91):        `fail332.bar(Object, int[2]...)` declared here
void bar(Object, int[2]...);
     ^
fail_compilation/fail332.d(99): Error: function `bar` is not callable using argument types `(typeof(null), int, string)`
    bar(null, 2, "");
       ^
fail_compilation/fail332.d(99):        cannot pass argument `""` of type `string` to parameter `int[2]...`
fail_compilation/fail332.d(91):        `fail332.bar(Object, int[2]...)` declared here
void bar(Object, int[2]...);
     ^
fail_compilation/fail332.d(100): Error: function `bar` is not callable using argument types `(typeof(null), int, int, int)`
    bar(null, 2,3,4);
       ^
fail_compilation/fail332.d(100):        expected 2 variadic argument(s), not 3
fail_compilation/fail332.d(91):        `fail332.bar(Object, int[2]...)` declared here
void bar(Object, int[2]...);
     ^
---
*/

import core.vararg;

void foo(int, ...) {}
void baz(int[]...) {}

void test()
{
    foo();
    foo(null);

    baz("");
    baz(3, null);
}

void bar(Object, int[2]...);

void test2()
{
    bar();
    bar(4);
    bar(null);
    bar(null, 2);
    bar(null, 2, "");
    bar(null, 2,3,4);
}
