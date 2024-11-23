/*
TEST_OUTPUT:
---
fail_compilation/fail20551.d(19): Error: cannot take address of lazy parameter `e` in `@safe` function `opAssign`
        dg = cast(typeof(dg)) &e;
                              ^
fail_compilation/fail20551.d(30): Error: template instance `fail20551.LazyStore!int.LazyStore.opAssign!int` error instantiating
    f = x + x + 20 + x * 20;
      ^
---
*/

struct LazyStore(T)
{
    T delegate() @safe dg;

    void opAssign(E)(lazy E e) @safe
    {
        dg = cast(typeof(dg)) &e;
    }

    T test() @safe{ return dg(); }
}

static LazyStore!int f;

void main(string[] args) @safe
{
    int x = 1;
    f = x + x + 20 + x * 20;
}
