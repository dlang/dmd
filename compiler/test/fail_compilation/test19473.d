/* TEST_OUTPUT:
---
fail_compilation/test19473.d(19): Error: union `test19473.P` no size because of forward reference
fail_compilation/test19473.d(19):        while resolving `test19473.P`
fail_compilation/test19473.d(30):        while resolving `test19473.A.UTpl!().UTpl`
fail_compilation/test19473.d(35):        while resolving `test19473.C.D`
fail_compilation/test19473.d(34):        while resolving `test19473.P`
fail_compilation/test19473.d(35):        error on member `test19473.P.p`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19473

struct A {
        P p;

        struct UTpl() {
                union {
                        P p;
                }
        }

        alias U = UTpl!();
}

alias B = A.U;

struct C {
        union D {
                B b;
        }
}

union P {
        C.D p;
}
