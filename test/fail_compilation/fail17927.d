/* REQUIRED_ARGS: -preview=dip1000
 * TEST_OUTPUT:
---
fail_compilation/fail17927.d(16): Error: scope parameter `this` may not be returned
fail_compilation/fail17927.d(16):        perhaps annotate the function with `return`
fail_compilation/fail17927.d(24): Error: scope parameter `ptr` may not be returned
fail_compilation/fail17927.d(24):        perhaps annotate the parameter with `return`
fail_compilation/fail17927.d(26): Error: scope parameter `ptr` may not be returned
fail_compilation/fail17927.d(26):        perhaps annotate the parameter with `return`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17927

struct String {
    const(char)* mem1() const scope @safe { return ptr; }

    inout(char)* mem2() inout scope @safe { return ptr; } // no error because `ref inout` implies `return`

    char* ptr;
}


const(char)* foo1(scope const(char)* ptr) @safe { return ptr; }

inout(char)* foo2(scope inout(char)* ptr) @safe { return ptr; }

