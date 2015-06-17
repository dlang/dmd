/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b 21
r
echo RESULT=
p 'gdb.x' + 'gdb.y'
---
GDB_MATCH: RESULT=.*4000065002
*/
module gdb;

__gshared uint x = 4_000_000_000;
__gshared ushort y = 65000;

void main()
{
    ++x; ++y;
    // BP
}
