/*
TEST_OUTPUT:
---
fail_compilation\fail332.d(32): Error: function `fail332.foo(int _param_0, ...)` is not callable using argument types `()`
fail_compilation\fail332.d(32):        expected 1 argument(s), not 0
fail_compilation\fail332.d(33): Error: function `fail332.foo(int _param_0, ...)` is not callable using argument types `(typeof(null))`
fail_compilation\fail332.d(33):        cannot pass argument `null` of type `typeof(null)` to parameter `int _param_0`
fail_compilation\fail332.d(35): Error: function `fail332.baz(int[] _param_0...)` is not callable using argument types `(string)`
fail_compilation\fail332.d(35):        cannot pass argument `""` of type `string` to parameter `int[] _param_0...`
fail_compilation\fail332.d(36): Error: function `fail332.baz(int[] _param_0...)` is not callable using argument types `(int, typeof(null))`
fail_compilation\fail332.d(36):        cannot pass argument `null` of type `typeof(null)` to parameter `int[] _param_0...`
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

/*
TEST_OUTPUT:
---
fail_compilation\fail332.d(50): Error: function `fail332.bar(Object, int[2]...)` is not callable using argument types `()`
fail_compilation\fail332.d(50):        expected 2 argument(s), not 0
fail_compilation\fail332.d(51): Error: function `fail332.bar(Object, int[2]...)` is not callable using argument types `(int)`
fail_compilation\fail332.d(51):        cannot pass argument `4` of type `int` to parameter `Object`
fail_compilation\fail332.d(52): Error: function `fail332.bar(Object, int[2]...)` is not callable using argument types `(typeof(null))`
fail_compilation\fail332.d(52):        expected 2 variadic argument(s), not 0
fail_compilation\fail332.d(53): Error: function `fail332.bar(Object, int[2]...)` is not callable using argument types `(typeof(null), int)`
fail_compilation\fail332.d(53):        expected 2 variadic argument(s), not 1
fail_compilation\fail332.d(54): Error: function `fail332.bar(Object, int[2]...)` is not callable using argument types `(typeof(null), int, string)`
fail_compilation\fail332.d(54):        cannot pass argument `""` of type `string` to parameter `int[2]...`
fail_compilation\fail332.d(55): Error: function `fail332.bar(Object, int[2]...)` is not callable using argument types `(typeof(null), int, int, int)`
fail_compilation\fail332.d(55):        expected 2 variadic argument(s), not 3
---
*/
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
