/*
REQUIRED_ARGS: -g
PERMUTE_ARGS:
GDB_SCRIPT:
---
b _Dmain
r
s
s
s
echo RESULT=
info args
---
GDB_MATCH: RESULT=__capture = 0x[0-9a-f]+\na = 7\nb = 8
*/

void main()
{
    Foo f;
    f.foo();
}

struct Foo
{
    void foo()
    {
        void bar(int a, int b)
        {
            
        }
        bar(7, 8);
    }
}
