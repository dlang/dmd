/*
DISABLED: osx
REQUIRED_ARGS: -vasm -betterC -checkaction=halt
TEST_OUTPUT:
---
main:
0000:   0F 0B                    ud2
0002:   31 C0                    xor       EAX,EAX
0004:   C3                       ret
---
*/

// Issue 23068 - [betterC] BetterC does not respect -checkaction=halt
// https://issues.dlang.org/show_bug.cgi?id=23068

extern(C) void main()
{
    assert(0);
}
