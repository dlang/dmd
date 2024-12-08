/* TEST_OUTPUT:
---
fail_compilation/test21665.d(22): Error: `void` initializers for structs with invariants are not allowed in safe functions
    ShortString s = void;
                ^
fail_compilation/test21665.d(34): Error: field `U.s` cannot access structs with invariants in `@safe` code that overlap other fields
    u.s.length = 3;
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=21665

struct ShortString {
    private ubyte length;
    private char[15] data;

    invariant { assert(length <= data.length); }
}

@safe void test1() {
    ShortString s = void;
}

union U
{
    int n;
    ShortString s;
}

@safe void test2()
{
    U u;
    u.s.length = 3;
}
