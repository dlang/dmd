/*
https://issues.dlang.org/show_bug.cgi?id=22311
REQUIRED_ARGS: -g -c -m64
GDB_SCRIPT:
---
print sizeof('int[]'::length)
---
GDB_MATCH: \$1 = 8
*/

int[] x;
