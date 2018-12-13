// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail7443.d(12): Deprecation: `static` has no effect on a constructor inside a `static` block. Use `static this()`
fail_compilation/fail7443.d(13): Deprecation: `shared static` has no effect on a constructor inside a `shared static` block. Use `shared static this()`
---
*/

class Foo
{
    public static { this() {}}
    public shared static { this() {}}
    public {this() {}}
}
