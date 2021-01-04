/* TEST_OUTPUT:
---
fail_compilation/fix20565.d(112): Error: declaration `fix20565.foo.temp(T)()` is already defined in another scope in `foo` at line `106`
fail_compilation/fix20565.d(114): Error: template instance `temp!int` `temp!int` forward references template declaration `temp(T)()`
---
*/

#line 100

// https://issues.dlang.org/show_bug.cgi?id=20565

void foo()
{
    {
        int temp(T)() { return 3; }

        temp!int();
    }

    {
        int temp(T)() { return 4; }

        temp!int();
    }
}

