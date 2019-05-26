/*
DISABLED: dragonflybsd freebsd linux osx win32
TEST_OUTPUT:
---
Error: cannot mix `core.std.stdlib.alloca()` and exception handling in `_Dmain()`
---
*/

import core.stdc.stdlib : alloca;
import core.stdc.stdio;

struct TheStruct
{
    ~this()
    {
        printf("dtor()\n");
    }
}

void bar()
{
    printf("bar()\n");
}

void main()
{
    auto s = TheStruct();
    bar();
    auto a = alloca(16);
    printf("test()\n");
}
