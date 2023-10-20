/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b gdb14276.d:21
r
echo RESULT=
p v[0] + v[1] + v[2] + v[3]
---
GDB_MATCH: RESULT=.*1234
*/
import core.simd;

void main()
{
    version (X86_64)
        int4 v = [1000, 200, 30, 4];
    else
        int[4] v = [1000, 200, 30, 4];
    // BP
}
