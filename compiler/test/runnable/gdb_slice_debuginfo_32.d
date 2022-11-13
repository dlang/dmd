/*
https://issues.dlang.org/show_bug.cgi?id=22311
REQUIRED_ARGS: -g -c -m32
GDB_SCRIPT:
---
print sizeof('int[]'::length)
---
GDB_MATCH: \$1 = 4
*/

int[] x;
