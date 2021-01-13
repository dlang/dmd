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
GDB_MATCH: RESULT=first = 2\nsecond = 2.2
*/

import core.stdc.stdarg;

void main()
{
    foo(2, 2.2, 2.3);
}

void foo(int first, float second, ...) { }

