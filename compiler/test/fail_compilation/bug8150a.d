// https://issues.dlang.org/show_bug.cgi?id=8150: nothrow check doesn't work for constructor
/*
TEST_OUTPUT:
---
fail_compilation/bug8150a.d(18): Error: `object.Exception` is thrown but not caught
        throw new Exception("something");
        ^
fail_compilation/bug8150a.d(16): Error: constructor `bug8150a.Foo.this` may throw but is marked as `nothrow`
    this(int) nothrow
    ^
---
*/

struct Foo
{
    this(int) nothrow
    {
        throw new Exception("something");
    }
}

void main() {
    Foo(1);
}
