// REQUIRED_ARGS: -d

// Test cases using deprecated features
module deprecate1;

import core.stdc.stdio : printf;

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


/******************************************/

int main()
{
    test19();
    test5();
    test59();
    test60();
    return 0;
}
