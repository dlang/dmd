/*
TEST_OUTPUT:
---
fail_compilation/ice11793.d(13): Error: circular reference to `ice11793.Outer.outer`
    Outer outer = new Outer();
                  ^
---
*/

class Outer
{
    int foo;
    Outer outer = new Outer();
}
