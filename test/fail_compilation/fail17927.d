/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/fail17927.d(14): Error: scope variable `this` may not be returned
fail_compilation/fail17927.d(16): Error: scope variable `this` may not be returned
fail_compilation/fail17927.d(22): Error: scope variable `ptr` may not be returned
fail_compilation/fail17927.d(24): Error: scope variable `ptr` may not be returned
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17927

struct String {
    const(char)* mem1() const scope @safe { return ptr; }

    inout(char)* mem2() inout scope @safe { return ptr; }

    char* ptr;
}


const(char)* foo1(scope const(char)* ptr) @safe { return ptr; }

inout(char)* foo2(scope inout(char)* ptr) @safe { return ptr; }

