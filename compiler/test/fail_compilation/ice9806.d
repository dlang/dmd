/*
TEST_OUTPUT:
---
fail_compilation/ice9806.d(42): Error: undefined identifier `undefined_expr`
struct S1() { enum x = undefined_expr; }
                       ^
fail_compilation/ice9806.d(47): Error: template instance `ice9806.S1!()` error instantiating
    auto sx = S1!().x;
              ^
fail_compilation/ice9806.d(43): Error: undefined identifier `undefined_expr`
class  C1() { enum x = undefined_expr; }
                       ^
fail_compilation/ice9806.d(49): Error: template instance `ice9806.C1!()` error instantiating
    auto cx = C1!().x;
              ^
fail_compilation/ice9806.d(44): Error: undefined identifier `undefined_expr`
class  I1() { enum x = undefined_expr; }
                       ^
fail_compilation/ice9806.d(51): Error: template instance `ice9806.I1!()` error instantiating
    auto ix = I1!().x;
              ^
fail_compilation/ice9806.d(54): Error: undefined identifier `undefined_expr`
int foo2()() { return undefined_expr; }
                      ^
fail_compilation/ice9806.d(62): Error: template instance `ice9806.S2!()` error instantiating
    auto sx = S2!().x;
              ^
fail_compilation/ice9806.d(55): Error: undefined identifier `undefined_expr`
int bar2()() { return undefined_expr; }
                      ^
fail_compilation/ice9806.d(64): Error: template instance `ice9806.C2!()` error instantiating
    auto cx = C2!().x;
              ^
fail_compilation/ice9806.d(56): Error: undefined identifier `undefined_expr`
int baz2()() { return undefined_expr; }
                      ^
fail_compilation/ice9806.d(66): Error: template instance `ice9806.I2!()` error instantiating
    auto ix = I2!().x;
              ^
---
*/
struct S1() { enum x = undefined_expr; }
class  C1() { enum x = undefined_expr; }
class  I1() { enum x = undefined_expr; }
void test1() {
    static assert(!is(typeof(S1!().x)));
    auto sx = S1!().x;
    static assert(!is(typeof(C1!().x)));
    auto cx = C1!().x;
    static assert(!is(typeof(I1!().x)));
    auto ix = I1!().x;
}

int foo2()() { return undefined_expr; }
int bar2()() { return undefined_expr; }
int baz2()() { return undefined_expr; }
struct S2() { enum x = foo2(); }
class  C2() { enum x = bar2(); }
class  I2() { enum x = baz2(); }
void test2() {
    static assert(!is(typeof(S2!().x)));
    auto sx = S2!().x;
    static assert(!is(typeof(C2!().x)));
    auto cx = C2!().x;
    static assert(!is(typeof(I2!().x)));
    auto ix = I2!().x;
}
