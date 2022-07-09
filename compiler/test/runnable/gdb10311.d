/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b gdb10311.d:19
r
echo RESULT=
p x
---
GDB_MATCH: RESULT=.*33
*/
void call(void delegate() dg) { dg(); }

void main()
{
    int x=32;
    call({++x;});
    // BP
}
