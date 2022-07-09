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
GDB_MATCH: RESULT=first = 1\nsecond = 1.2
*/

void main()
{
    foo(1, 1.2);
}

void foo(int first, float second) { }
