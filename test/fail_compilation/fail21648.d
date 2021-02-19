// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail21648.d(10): Error: undefined identifier `semantics`
---
*/

template bla() {
    semantics error;
}

struct Type {
    enum e = __traits(compiles, Type.init);
    static if (bla!()) { }
}
