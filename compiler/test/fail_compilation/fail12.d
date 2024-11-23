/*
TEST_OUTPUT:
---
fail_compilation/fail12.d(23): Error: `abc` matches conflicting symbols:
    assert(abc() == 8);
              ^
fail_compilation/fail12.d(15):        function `fail12.main.Foo!(y).abc`
    int abc() { return b; }
        ^
fail_compilation/fail12.d(15):        function `fail12.main.Foo!(y).abc`
---
*/
template Foo(alias b)
{
    int abc() { return b; }
}

void main()
{
    int y = 8;
    mixin Foo!(y);
    mixin Foo!(y);
    assert(abc() == 8);
}
