/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b 17
r
echo RESULT=
p x
---
GDB_MATCH: RESULT=.*33
*/

void foo(ref int x)
{
    ++x;
    // BP
}

void main()
{
    auto x = 32;
    foo(x);
}
