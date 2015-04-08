/*
TEST_OUTPUT:
---
fail_compilation/fail4923.d(9): Error: variable fail4923.x can only initialize immutable global variable inside shared static constructor
fail_compilation/fail4923.d(10): Error: variable fail4923.y can only initialize shared global variable inside shared static constructor
fail_compilation/fail4923.d(11): Error: variable fail4923.z can only initialize immutable global variable inside shared static constructor
fail_compilation/fail4923.d(16): Error: variable fail4923.w can only initialize unshared global variable inside static constructor
---
*/

#line 1
int w;
immutable int x;
shared int y;
shared immutable int z;

static this()
{
    w = 6;
    x = 7;
    y = 8;
    z = 9;
}

shared static this()
{
    w = 6;
    x = 7;
    y = 8;
    z = 9;
}

void main()
{
}
