// https://issues.dlang.org/show_bug.cgi?id=23535

import core.stdc.stdio;

immutable int x;

pragma(crt_constructor) void initty() { x = 1; }

pragma(crt_destructor) void dtorty() { }

int main()
{
    assert(x == 1);
    printf("x = %d\n", x);
    return 0;
}
