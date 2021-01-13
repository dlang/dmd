/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b _Dmain
r
s
echo RESULT=
info args
---
GDB_MATCH: RESULT=__HID1 = 0x[0-9a-f]+\nthis = @0x[0-9a-f]+: {x = 4}\nb = 5\na = 4

*/

void main()
{
    S(4).foo(4, 5);
}

struct S
{
    int x;

    ~this() {}
    S foo(int a, float b)
    {
        return S(x + a);
    }
}
