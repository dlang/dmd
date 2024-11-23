// https://issues.dlang.org/show_bug.cgi?id=5153

/*
TEST_OUTPUT:
---
fail_compilation/fail5153.d(28): Error: cannot implicitly convert expression `new Foo(0)` of type `Foo*` to `Foo`
    Foo f = new Foo(0);
        ^
fail_compilation/fail5153.d(28):        Perhaps remove the `new` keyword?
---
*/

class Foo2
{
    this(int) {}
}

struct Foo {
    int x;
    this(int x_)
    {
        this.x = x_;
    }

    this(Foo2) {}
}
void main() {
    Foo f = new Foo(0);
    Foo f2 = new Foo2(0);
}
