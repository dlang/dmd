/*
TEST_OUTPUT:
---
fail_compilation/fail99.d(15): Error: delegate `dg(int)` is not callable using argument types `()`
    dg();
      ^
fail_compilation/fail99.d(15):        too few arguments, expected 1, got 0
---
*/

//import std.stdio;

void foo(void delegate(int) dg)
{
    dg();
    //writefln("%s", dg(3));
}

void main()
{
    foo(delegate(int i)
        {
            //writefln("i = %d\n", i);
        }
       );
}
