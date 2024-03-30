/*
REQUIRED_ARGS: -de -preview=unsafeFieldInit
TEST_OUTPUT:
---
fail_compilation/unsafe_field_init.d(16): Deprecation: field `unsafe_field_init.C.x` of darray type cannot be (tail) mutable and have an initializer
fail_compilation/unsafe_field_init.d(16):        Either use constructors to initialize the field, or mark it as `@system`
fail_compilation/unsafe_field_init.d(29): Deprecation: field `unsafe_field_init.S.a` of darray type cannot be (tail) mutable and have an initializer
fail_compilation/unsafe_field_init.d(29):        Either use constructors to initialize the field, or mark it as `@system`
fail_compilation/unsafe_field_init.d(31): Deprecation: field `unsafe_field_init.S.o` of class type cannot be mutable and have an initializer
fail_compilation/unsafe_field_init.d(31):        Either use constructors to initialize the field, or mark it as `@system`
fail_compilation/unsafe_field_init.d(34): Deprecation: field `unsafe_field_init.S.p` of pointer type cannot be (tail) mutable and have an initializer
fail_compilation/unsafe_field_init.d(34):        Either use constructors to initialize the field, or mark it as `@system`
---
*/

class C { int[] x=[1,2,3]; }

void main() {
    auto c = new immutable(C)();
    auto d = new C();
    static assert(is(typeof(c.x[0])==immutable));
    assert(c.x[0]==1);
    d.x[0]=2;
    assert(c.x[0]==2);
}

struct S {
    enum e = [1, 2];
    int[] a = e;
    const(int)[] b = e; // OK
    auto o = new Exception("");
    //Rebindable!(const Exception) ro = new Exception(""); // TODO: OK
    shared int[] sa = [1, 2]; // assume OK
    P* p = new P;
    const(P)* q = new P; // OK, tail const
    @system P* r = new P; // OK

    static P s;
    static sm = [1, 2]; // OK
}
struct P {}
