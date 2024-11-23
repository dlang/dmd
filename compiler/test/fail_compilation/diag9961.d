/*
TEST_OUTPUT:
---
fail_compilation/diag9961.d(19): Error: cannot implicitly convert expression `""` of type `string` to `int`
void foo(T)(T) { int x = ""; }
                         ^
fail_compilation/diag9961.d(22): Error: template instance `diag9961.foo!int` error instantiating
    100.foo();
           ^
fail_compilation/diag9961.d(19): Error: cannot implicitly convert expression `""` of type `string` to `int`
void foo(T)(T) { int x = ""; }
                         ^
fail_compilation/diag9961.d(23): Error: template instance `diag9961.foo!char` error instantiating
    'a'.foo;
       ^
---
*/

void foo(T)(T) { int x = ""; }
void main()
{
    100.foo();
    'a'.foo;
}
