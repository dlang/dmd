/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b gdb4181.d:22
r
echo RESULT=
p 'gdb.x' + 'gdb.STest.y'
---
GDB_MATCH: RESULT=.*33
*/
module gdb;

int x;
struct STest { static int y; }

void main()
{
    x = 11;
    STest.y = 22;
    // BP
}
