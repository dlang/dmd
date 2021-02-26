/*
https://issues.dlang.org/show_bug.cgi?id=10619

PERMUTE_ARGS:
RUN_OUTPUT:
---
1
1
3
4
---

print => 2 will be fixed by https://github.com/dlang/dmd/pull/12235
*/

void main()
{
    {
        int x = 1;
        print!x();
    }
    {
        int x = 2;
        print!x();
    }
    {
        static int y = 3;
        print!y();
    }
    {
        static int y = 4;
        print!y();
    }
}

void print(alias symbol)()
{
    import core.stdc.stdio : printf;
    printf("%d\n", symbol);
}
