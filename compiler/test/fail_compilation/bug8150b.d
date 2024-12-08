// https://issues.dlang.org/show_bug.cgi?id=8150: nothrow check doesn't work for constructor
/*
TEST_OUTPUT:
---
fail_compilation/bug8150b.d(21): Error: `object.Exception` is thrown but not caught
        throw new Exception("something");
        ^
fail_compilation/bug8150b.d(19): Error: constructor `bug8150b.Foo.__ctor!().this` may throw but is marked as `nothrow`
    this()(int) nothrow
    ^
fail_compilation/bug8150b.d(26): Error: template instance `bug8150b.Foo.__ctor!()` error instantiating
    Foo(1);
       ^
---
*/

struct Foo
{
    this()(int) nothrow
    {
        throw new Exception("something");
    }
}

void main() {
    Foo(1);
}
