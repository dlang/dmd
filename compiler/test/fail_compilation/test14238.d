/* REQUIRED_ARGS: -preview=dip1000
   TEST_OUTPUT:
---
fail_compilation/test14238.d(30): Error: scope parameter `fn` may not be returned
    return fn(); // Error
             ^
fail_compilation/test14238.d(33): Error: function `test14238.bar` is `@nogc` yet allocates closure for `bar()` with the GC
ref int bar() @nogc {
        ^
fail_compilation/test14238.d(35):        function `test14238.bar.baz` closes over variable `x`
    ref int baz() {
            ^
fail_compilation/test14238.d(34):        `x` declared here
    int x;
        ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=14238

@safe:

alias Fn = ref int delegate() return @nogc;

ref int call(return scope Fn fn) @nogc
{
    return fn(); // Ok
}

ref int foo2(scope Fn fn) {
    return fn(); // Error
}

ref int bar() @nogc {
    int x;
    ref int baz() {
            return x;
    }

    if (x == 0)
        return call(&baz);
    else
        return (&baz)();
}
