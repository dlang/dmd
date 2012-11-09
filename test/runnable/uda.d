
import core.stdc.stdio;

template Tuple(T...)
{
     alias T Tuple;
}



enum EEE = 7;
@("hello") struct SSS { }

@(3) { @(4)@(EEE)@(SSS) int foo; }

pragma(msg, __traits(getAttributes, foo));

alias Tuple!(__traits(getAttributes, foo)) TP;

pragma(msg, TP);
pragma(msg, TP[2]);
TP[3] a;
pragma(msg, typeof(a));


alias Tuple!(__traits(getAttributes, typeof(a))) TT;

pragma(msg, TT);

@('c') string s;
pragma(msg, __traits(getAttributes, s));

/************************************************/

enum FFF;
@(FFF) int x1;
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

@(1) void foo4();
@(2) void foo4(int x);

void test4()
{
    int i = 1;
    foreach (o; __traits(getOverloads, uda, "foo4"))
    {
        alias Tuple!(__traits(getAttributes, o)) attrs;
        pragma(msg, attrs.stringof);
	assert(attrs[0] == i);
	++i;
    }
}

/************************************************/

pragma(msg, __traits(getAttributes, aa));
alias Tuple!(__traits(getAttributes, aa)) Taa;
@(10) int aa;

pragma(msg, __traits(getAttributes, bb));
alias Tuple!(__traits(getAttributes, bb)) Tbb;
@(20) int bb;
alias Tuple!(__traits(getAttributes, bb)) Tbbc;

@(30) int cc;
pragma(msg, __traits(getAttributes, cc));
alias Tuple!(__traits(getAttributes, cc)) Tcc;

void test5()
{
    assert(Taa[0] == 10);
    assert(Tbb[0] == 20);
    assert(Tbbc[0] == 20);
    assert(Tcc[0] == 30);
}

/************************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();

    printf("Success\n");
    return 0;
}
