/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b 22
r
echo RESULT=
p e
---
GDB_MATCH: RESULT=.*TestEnum\.Item0
*/
enum TestEnum
{
    Item0,
    Item1
}

void main()
{
    TestEnum e;
}
