// REQUIRED_ARGS: -d

// Test cases using deprecated features
module deprecate1;

import core.stdc.stdio : printf;
import std.traits;


/**************************************
            volatile
**************************************/
void test5a(int *j)
{
    int i;

    volatile i = *j;
    volatile i = *j;
}

void test5()
{
    int x;

    test5a(&x);
}

/**************************************
        octal literals
**************************************/

void test10()
{
    int b = 0b_1_1__1_0_0_0_1_0_1_0_1_0_;
    assert(b == 3626);

    b = 0_1_2_3_4_;
    printf("b = %d\n", b);
    assert(b == 668);
}

/**************************************
            typedef
**************************************/

template func19( T )
{
    typedef T function () fp = &erf;
    T erf()
    {
	printf("erf()\n");
	return T.init;
    }
}

alias func19!( int ) F19;

F19.fp tc;

void test19()
{
    printf("tc = %p\n", tc);
    assert(tc() == 0);
}


/**************************************/

// http://www.digitalmars.com/d/archives/digitalmars/D/bugs/578.html

typedef void* T60;

class A60
{
     int  List[T60][int][uint];

     void GetMsgHandler(T60 h,uint Msg)
     {
         assert(Msg in List[h][0]);    //Offending line
     }
}

void test60()
{
}

/**************************************/
// http://www.digitalmars.com/d/archives/digitalmars/D/bugs/576.html

typedef ulong[3] BBB59;

template A59()
{
    void foo(BBB59 a)
    {
	printf("A.foo\n");
	bar(a);
    }
}

struct B59
{
    mixin A59!();

    void bar(BBB59 a)
    {
	printf("B.bar\n");
    }
}

void test59()
{
    ulong[3] aa;
    BBB59 a;
    B59 b;

    b.foo(a);
}

/***************************************/
// From variadic.d

template foo33(TA...)
{
  const TA[0] foo33=0;
}

template bar33(TA...)
{
  const TA[0..1][0] bar33=TA[0..1][0].init;
}

void test33()
{
    typedef int dummy33=0;
    typedef int myint=3;

    assert(foo33!(int)==0);
    assert(bar33!(int)==int.init);
    assert(bar33!(myint)==myint.init);
    assert(foo33!(int,dummy33)==0);
    assert(bar33!(int,dummy33)==int.init);
    assert(bar33!(myint,dummy33)==myint.init);
}

/***************************************/
// Bug 875  ICE(glue.c)

void test41()
{
    double bongos(int flux, string soup)
    {
        return 0.0;
    }

    auto foo = mk_future(& bongos, 99, "soup"[]);
}

int mk_future(A, B...)(A cmd, B args)
{
    typedef ReturnType!(A) TReturn;
    typedef ParameterTypeTuple!(A) TParams;
    typedef B TArgs;

    alias Foo41!(TReturn, TParams, TArgs) TFoo;

    return 0;
}

class Foo41(A, B, C) {
    this(A delegate(B), C)
    {
    }
}


/******************************************/

int main()
{
    test5();
    test10();
    test19();
    test33();
    test41();
    test59();
    test60();
    return 0;
}
