
import core.stdc.stdio;

enum EEE = 7;
["hello"] struct SSS { }

[3] { [4][EEE][SSS] int foo; }

pragma(msg, __traits(getAttributes, foo));

template Tuple(T...)
{
     alias T Tuple;
}

alias Tuple!(__traits(getAttributes, foo)) TP;

pragma(msg, TP);
pragma(msg, TP[2]);
TP[3] a;
pragma(msg, typeof(a));


alias Tuple!(__traits(getAttributes, typeof(a))) TT;

pragma(msg, TT);

['c'] string s;
pragma(msg, __traits(getAttributes, s));

/************************************************/

enum FFF;
[FFF] int x1;
pragma(msg, __traits(getAttributes, x1));

void test1()
{
    alias Tuple!(__traits(getAttributes, x1)) tp;
    assert(tp.length == 1);
    if (!is(FFF == tp[0]))
	assert(0);
}

/************************************************/

void test2()
{
    int x;
    alias Tuple!(__traits(getAttributes, x)) tp;
    assert(tp.length == 0);
}

/************************************************/

void test3()
{
    alias Tuple!(__traits(getAttributes, foo)) tp;
    assert(tp.length == 4);
    assert(tp[0] == 3);
    assert(tp[1] == 4);
    assert(tp[2] == 7);
}

/************************************************/

int main()
{
    test1();
    test2();
    test3();

    printf("Success\n");
    return 0;
}
