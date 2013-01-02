/*
TEST_OUTPUT:
---
fail_compilation/diag9250.d(13): Error: cannot implicitly convert expression (10u) of type uint to Foo
---
*/

struct Foo { }

void main()
{
    uint[10] bar;
    Foo x = bar.length;
}
