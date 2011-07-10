// PERMUTE_ARGS:

module breaker;

import std.c.stdio;

/**********************************/

U foo(T, U)(U i)
{
    return i + 1;
}

int foo(T)(int i)
{
    return i + 2;
}

void test1()
{
    auto i = foo!(int)(2L);
//    assert(i == 4);    // now returns 3
}

/**********************************/

U foo2(T, U)(U i)
{
    return i + 1;
}

void test2()
{
    auto i = foo2!(int)(2L);
    assert(i == 3);
}

/**********************************/

class Foo3
{
    T bar(T,U)(U u)
    {
	return cast(T)u;
    }
}

void test3()
{
  Foo3 foo = new Foo3;
  int i = foo.bar!(int)(1.0);
  assert(i == 1);
} 


/**********************************/

T* begin4(T)(T[] a) { return a.ptr; }

void copy4(string pred = "", Ranges...)(Ranges rs)
{
    alias rs[$ - 1] target;
    pragma(msg, typeof(target).stringof);
    auto tb = begin4(target);//, te = end(target);
}

void test4()
{
    int[] a, b, c;
    copy4(a, b, c);
    // comment the following line to prevent compiler from crashing
    copy4!("a > 1")(a, b, c);
}

/**********************************/

import std.stdio:writefln;

template foo5(T,S)
{
    void foo5(T t, S s) {
        writefln("typeof(T)=",typeid(T)," typeof(S)=",typeid(S));
    }
}

template bar5(T,S)
{
    void bar5(S s) {
        writefln("typeof(T)=",typeid(T),"typeof(S)=",typeid(S));
    }
}


void test5()
{
    foo5(1.0,33);
    bar5!(double,int)(33);
    bar5!(float)(33); 
}

/**********************************/

int foo6(T...)(auto ref T x)
{   int result;

    foreach (i, v; x)
    {
	if (v == 10)
	    assert(__traits(isRef, x[i]));
	else
	    assert(!__traits(isRef, x[i]));
	result += v;
    }
    return result;
}

void test6()
{   int y = 10;
    int r;
    r = foo6(8);
    assert(r == 8);
    r = foo6(y);
    assert(r == 10);
    r = foo6(3, 4, y);
    assert(r == 17);
    r = foo6(4, 5, y);
    assert(r == 19);
    r = foo6(y, 6, y);
    assert(r == 26);
}

/**********************************/

auto ref min(T, U)(auto ref T lhs, auto ref U rhs)
{
    return lhs > rhs ? rhs : lhs;
}

void test7()
{   int x = 7, y = 8;
    int i;

    i = min(4, 3);
    assert(i == 3);
    i = min(x, y);
    assert(i == 7);
    min(x, y) = 10;
    assert(x == 10);
    static assert(!__traits(compiles, min(3, y) = 10));
    static assert(!__traits(compiles, min(y, 3) = 10));
}

/**********************************/
// 5946

template TTest8()
{
    int call(){ return this.g(); }
}
class CTest8
{
    int f() { mixin TTest8!(); return call(); }
    int g() { return 10; }
}
void test8()
{
    assert((new CTest8()).f() == 10);
}

/**********************************/
// 693

template TTest9(alias sym)
{
    int call(){ return sym.g(); }
}
class CTest9
{
    int f1() { mixin TTest9!(this); return call(); }
    int f2() { mixin TTest9!this; return call(); }
    int g() { return 10; }
}
void test9()
{
    assert((new CTest9()).f1() == 10);
    assert((new CTest9()).f2() == 10);
}

/**********************************/
// 5015

import breaker;

static if (is(ElemType!(int))){}

template ElemType(T) {
  alias _ElemType!(T).type ElemType;
}

template _ElemType(T) {
    alias r type;
}

/**********************************/

void bug4984a(int n)() if (n > 0 && is(typeof(bug4984a!(n-1) ()))) {
}

void bug4984a(int n : 0)() {
}

void bug4984b(U...)(U args) if ( is(typeof( bug4984b(args[1..$]) )) ) {
}

void bug4984b(U)(U u) {
}

void bug4984() {
    bug4984a!400();
    bug4984b(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19);
}

/**********************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    bug4984();

    printf("Success\n");
    return 0;
}
