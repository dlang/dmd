// REQUIRED_ARGS:

import std.c.stdio;

/********************************************************/

//int delegate(int, char[]) *p;

class Foo
{
   int bar(int i, char[] s) { return 4; }
}

class Bar : Foo
{
   override int bar(int i, char[] s) { return 5; }
}

void test1()
{
	int delegate(int, char[]) dg;
	Foo f = new Foo();
	Bar b = new Bar();
	int x;

	dg = &f.bar;
	x = dg(3, null);
	assert(x == 4);

	f = b;
	dg = &f.bar;
	x = dg(3, null);
	assert(x == 5);
}

/********************************************************/

int foo2()
{
    return 3;
}

void test2()
{
    int function () fp;

    fp = &foo2;
    assert(fp() == 3);
}

/********************************************************/

class Foo3
{
    int bar(int i, char[] s) { return 47; }

    void test()
    {
	int delegate(int, char[]) dg;

	dg = &bar;
	printf("%d %d\n", dg(3, null), result());
	assert(dg(3, null) == result());

	dg = &this.bar;
	printf("%d %d\n", dg(3, null), result());
	assert(dg(3, null) == result());
    }

    int result() { return 47; }
}

class Bar3 : Foo3
{
    override int bar(int i, char[] s) { return 48; }

    override int result() { return 48; }

    void test2()
    {
	int delegate(int, char[]) dg;

	dg = &super.bar;
	assert(dg(3, null) == 47);
    }

}

void test3()
{
    Foo3 f = new Foo3();
    f.test();

    Bar3 b = new Bar3();
    b.test();
    b.test2();
}

/********************************************************/


int foo4(int x) { return 1; }
int foo4(char x) { return 2; }
int foo4(int x, int y) { return 3; }

void test4()
{
    int function (char) fp;

    fp = &foo4;
    assert(fp(0) == 2);
}

/********************************************************/

class Abc
{
    int foo1(int x) { return 1; }
    int foo1(char x) { return 2; }
    int foo1(int x, int y) { return 3; }
}

void test5()
{
    int delegate(char) dg;
    Abc a = new Abc();

    dg = &a.foo1;
    assert(dg(0) == 2);
}

/********************************************************/

int delegate(int) bar6;

int[int delegate(int)] aa6;

void test6()
{
    aa6[bar6] = 0;
}

/********************************************************/

void foo7(void delegate(int) dg)
{
    dg(1);
    //writefln("%s", dg(3));
}

void test7()
{
    foo7(delegate(int i)
	{
	    printf("i = %d\n", i);
	}
       );
}

/********************************************************/

void foo8(int delegate(int) dg)
{
    printf("%d\n", dg(3));
    assert(dg(3) == 6);
}

void test8()
{
    foo8(delegate(int i)
	{
	    return i * 2;
	}
       );
}

/********************************************************/

void foo9(int delegate(int) dg)
{
    assert(dg(3) == 6);
}

void test9()
{
    foo9( (int i) { return i * 2; } );
}

/********************************************************/

void foo10(int delegate() dg)
{
    assert(dg() == 6);
}

void test10()
{   int i = 3;

    foo10( { return i * 2; } );
}

/********************************************************/

class Foo11 {
    int x = 7;
    int func() { return x; }
}

void test11()
{
    int delegate() dg;
    Foo11 f = new Foo11;
    dg.ptr = cast(void*)f;
    dg.funcptr = &Foo11.func;
    assert(dg() == 7);
}

/********************************************************/

class A12
{
public:
  int delegate(int, int) dgs[4];
  int function(int, int) fps[4];
  int delegate(int, int) dg;
  int function(int, int) fp;
  int f(int x, int y) {
    printf("here ");
    int res = x + y;
    printf("%d\n", res);
    return res;
  }

  void bug_1() {
//    fp = &f;
//    fp(1,2);
    dg = &f;
    dg(1,2);
//    fps[] = [&f, &f, &f, &(f)];  // bug 1: this line shouldn't compile
//    this.fps[0](1, 2);  // seg-faults here!

    dgs[] = [&(f), &(f), &(f), &(f)];  // bug 1: why this line can't compile?
    this.dgs[0](1, 2);

    dgs[] = [&(this.f), &(this.f), &(this.f), &(this.f)];
    this.dgs[0](1, 2);
  }

}

void test12()
{
  A12 a = new A12();

  a.bug_1();
}

/********************************************************/
// 1570

class A13
{
    int f()
    {
        return 1;
    }
}

class B13 : A13
{
    override int f()
    {
        return 2;
    }
}

void test13()
{
    B13 b = new B13;
    assert(b.f() == 2);
    assert(b.A13.f() == 1);
    assert((&b.f)() == 2);
    assert((&b.A13.f)() == 1);
}

/********************************************************/

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
    test10();
    test11();
    test12();
    test13();

    printf("Success\n");
    return 0;
}
