// https://issues.dlang.org/show_bug.cgi?id=23452

/*
TEST_OUTPUT:
---
fail_compilation/fail23452.d(24): Error: struct `fail23452.Foo` is not copyable because it has a disabled postblit
fail_compilation/fail23452.d(24): Error: struct `fail23452.Foo` is not copyable because it has a disabled postblit
---
*/
import std.stdio;

struct Foo
{
    @disable this(this);
    int x;
}

void test(Foo[] foos...) {}

void main()
{
    Foo f1 = Foo(1);
    Foo f2 = Foo(2);
    test(f1, f2);
}
