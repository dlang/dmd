// https://issues.dlang.org/show_bug.cgi?id=20376

/*
TEST_OUTPUT:
---
fail_compilation/fail20376.d(19): Error: cannot implicitly convert expression `Foo()` of type `Foo` to `ubyte`
    return Foo();
              ^
---
*/

struct Foo
{
    this(ref scope Foo);
}

ubyte fun()
{
    return Foo();
}

void main(){}
