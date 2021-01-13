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
GDB_MATCH: RESULT=first = 3\nsecond = 3.2
*/

void main()
{
    foo(3, 3.2);
}

extern(C) void foo(int first, float second) { }

