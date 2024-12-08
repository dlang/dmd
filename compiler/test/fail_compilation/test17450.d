/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test17450.d(32): Error: returning `&s.bar` escapes a reference to parameter `s`
        return &s.bar;
               ^
fail_compilation/test17450.d(31):        perhaps annotate the parameter with `return`
    @safe dg_t foo1(ref S s) {
                          ^
fail_compilation/test17450.d(35): Error: returning `&this.bar` escapes a reference to parameter `this`
        return &bar;
               ^
fail_compilation/test17450.d(34):        perhaps annotate the function with `return`
    @safe dg_t foo2() {
               ^
fail_compilation/test17450.d(52): Error: scope parameter `c` may not be returned
        return &c.bar;
               ^
fail_compilation/test17450.d(55): Error: scope parameter `this` may not be returned
        return &bar;
               ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=17450
// https://issues.dlang.org/show_bug.cgi?id=17450

alias dg_t = void delegate();

struct S {
    @safe dg_t foo1(ref S s) {
        return &s.bar;
    }
    @safe dg_t foo2() {
        return &bar;
    }

    @safe dg_t foo3(return ref S s) {
        return &s.bar;
    }
    @safe dg_t foo4() return {
        return &bar;
    }

    @safe void bar();
}

// Line 100 starts here

class C {
    @safe dg_t foo1(scope C c) {
        return &c.bar;
    }
    @safe dg_t foo2() scope {
        return &bar;
    }

    @safe dg_t foo3(return scope C c) {
        return &c.bar;
    }
    @safe dg_t foo4() return scope {
        return &bar;
    }

    @safe void bar();
}
