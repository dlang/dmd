/*
TEST_OUTPUT:
---
fail_compilation/fail7443.d(12): Error: `static` has no effect on a constructor inside a `static` block. Use `static this()`
fail_compilation/fail7443.d(13): Error: `shared static` has no effect on a constructor inside a `shared static` block. Use `shared static this()`
fail_compilation/fail7443.d(14): Error: constructor `fail7443.Foo.this` constructor `fail7443.Foo.this()` conflicts with previous declaration at fail_compilation/fail7443.d(12)
---
*/

class Foo
{
    public static { this() {}}
    public shared static { this() {}}
    public {this() {}}
}
