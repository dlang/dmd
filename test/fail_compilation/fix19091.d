/* TEST_OUTPUT:
---
fail_compilation/fix19091.d(18): Error: function `fix19091.foo!().foo` has errors and cannot be called
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19091

// gag the foo error
static assert(!__traits(compiles, foo()));

void foo()() {
    static assert(false);
    bar!();
}

// foo() is not errored while bar compiles? because circular
void bar()() { foo(); }

// no error
void test() { bar(); }
