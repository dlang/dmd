// https://issues.dlang.org/show_bug.cgi?id=23452

/*
TEST_OUTPUT:
---
fail_compilation/fail23452.d(24): Error: struct `fail23452.Foo` is not copyable because it has a disabled postblit
fail_compilation/fail23452.d(24): Error: struct `fail23452.Foo` is not copyable because it has a disabled postblit
fail_compilation/fail23452.d(26): Error: copy constructor `fail23452.NoCopy.this` cannot be used because it is annotated with `@disable`
---
*/

struct Foo
{
    @disable this(this);
    int x;
}

void test(E)(E[] foos...) {}

void main()
{
    Foo f1 = Foo(1);
    Foo f2 = Foo(2);
    test(f1, f2);
    NoCopy nc;
    test(nc);
}

struct NoCopy
{
    @disable this(ref NoCopy);
    int x;
}
