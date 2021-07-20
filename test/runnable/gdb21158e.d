/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b _Dmain
r
s
s
echo RESULT=
info args
---
GDB_MATCH: RESULT=this = 0x[0-9a-f]+\nfirst = 4\nsecond = 5\n_arguments_typeinfo = 0x[0-9a-f]+
*/
import core.stdc.stdarg;

void main()
{
    Foo f = new Foo();
    f.foo(4, 5, 6, 7, 8);
}

class Foo
{
    void foo(int first, int second, ...) { }
}

