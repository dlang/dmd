module mul9377b;

import core.stdc.stdio;

int j;

int foo()()
{
    printf("foo()\n");
    static int z = 7;
    assert(z != 10);
    return ++z;
}

void bar()
{
    assert(j == 7);
    foo();
    printf("bar\n");
}

template def()
{
    alias int defint;

    static this()
    {
        printf("def.static this()\n");
        j = 7;
    }

    //void mem(int){}
    void mem()
    {
        printf("def().mem()\n");
    }
}

def!().defint x;

