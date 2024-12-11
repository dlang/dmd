/*
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test16193.d(45): Error: function `test16193.abc` is `@nogc` yet allocates closure for `abc()` with the GC
void abc() @nogc {
     ^
fail_compilation/test16193.d(47):        delegate `test16193.abc.__foreachbody_L47_C5` closes over variable `x`
    foreach(i; S.init) {
    ^
fail_compilation/test16193.d(46):        `x` declared here
    int x = 0;
        ^
---
*/
//fail_compilation/test16193.d(22): To enforce `@safe`, the compiler allocates a closure unless `opApply()` uses `scope`
//fail_compilation/test16193.d(34): To enforce `@safe`, the compiler allocates a closure unless `opApply()` uses `scope`
//fail_compilation/test16193.d(41): To enforce `@safe`, the compiler allocates a closure unless `opApply()` uses `scope`

// https://issues.dlang.org/show_bug.cgi?id=16193

struct S {
    int opApply(int delegate(int) dg) @nogc;
}

void foo() {
    int x = 0;
    foreach(i; S.init) {
        x++;
    }
}

struct T {
    int opApply(scope int delegate(int) dg) @nogc;
}


void bar() @nogc {
    int x = 0;
    foreach(i; T.init) {
        x++;
    }
}

void abc() @nogc {
    int x = 0;
    foreach(i; S.init) {
        x++;
    }
}
