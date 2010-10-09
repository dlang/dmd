// REQUIRED_ARGS: -d

import std.c.stdio;

/*******************************************/

int bar(int a)
{
    int foo(int b) { return b + 1; }

    return foo(a);
}

void test1()
{
    assert(bar(3) == 4);
}

/*******************************************/

int bar2(int a)
{
    static int c = 4;

    int foo(int b) { return b + c + 1; }

    return foo(a);
}

void test2()
{
    assert(bar2(3) == 8);
}


/*******************************************/

int bar3(int a)
{
    static int foo(int b) { return b + 1; }

    return foo(a);
}

void test3()
{
    assert(bar3(3) == 4);
}

/*******************************************/

int bar4(int a)
{
    static int c = 4;

    static int foo(int b) { return b + c + 1; }

    return foo(a);
}

void test4()
{
    assert(bar4(3) == 8);
}


/*******************************************/

int bar5(int a)
{
    int c = 4;

    int foo(int b) { return b + c + 1; }

    return c + foo(a);
}

void test5()
{
    assert(bar5(3) == 12);
}


/*******************************************/

int bar6(int a)
{
    int c = 4;

    int foob(int b) { return b + c + 1; }
    int fooa(int b) { return foob(c + b) * 7; }

    return fooa(a);
}

void test6()
{
    assert(bar6(3) == 84);
}


/*******************************************/

int bar7(int a)
{
    static int c = 4;

    static int foob(int b) { return b + c + 1; }

    int (*fp)(int) = &foob;

    return fp(a);
}

void test7()
{
    assert(bar7(3) == 8);
}

/*******************************************/

int bar8(int a)
{
    int c = 4;

    int foob(int b) { return b + c + 1; }

    int delegate(int) fp = &foob;

    return fp(a);
}

void test8()
{
    assert(bar8(3) == 8);
}


/*******************************************/

struct Abc9
{
    int a;
    int b;
    int c = 7;

    int bar(int x)
    {
	Abc9 *foo() { return &this; }

	Abc9 *p = foo();
	assert(p == &this);
	return p.c + x;
    }
}

void test9()
{
    Abc9 x;

    assert(x.bar(3) == 10);
}

/*******************************************/

class Abc10
{
    int a;
    int b;
    int c = 7;

    int bar(int x)
    {
	Abc10 foo() { return this; }

	Abc10 p = foo();
	assert(p == this);
	return p.c + x;
    }

}

void test10()
{
    Abc10 x = new Abc10();

    assert(x.bar(3) == 10);
}


/*******************************************/

class Collection
{
    int[3] array;

    void opApply(void delegate(int) fp)
    {
	for (int i = 0; i < array.length; i++)
	    fp(array[i]);
    }
}

int func11(Collection c)
{
    int max = int.min;

    void comp_max(int i)
    {
	if (i > max)
	    max = i;
    }

    c.opApply(&comp_max);
    return max;
}

void test11()
{
    Collection c = new Collection();

    c.array[0] = 7;
    c.array[1] = 26;
    c.array[2] = 25;

    int m = func11(c);
    assert(m == 26);
}


/*******************************************/

void SimpleNestedFunction ()
{
    int nest () { return 432; }

    assert (nest () == 432);
    int delegate () func = &nest;
    assert (func () == 432);
}

void AccessParentScope ()
{
    int value = 9;

    int nest () { assert (value == 9); return 9; }

    assert (nest () == 9);
}

void CrossNestedScope ()
{
    int x = 45;

    void foo () { assert (x == 45); }
    void bar () { int z = 16; foo (); }
    bar ();
}

void BadMultipleNested ()
{
    int x;

    void foo ()
    {
       void bar ()
       {
           //erroneous x = 4; // Should fail.
       }
    }
}

/* This one kind of depends upon memory layout.  GlobalScopeSpoof should 
be called with no "this" pointer; this is trying to ensure that 
everything is working properly.  Of course, in the DMD calling 
convention it'll fail if the caller passes too much/little data. */

void GlobalScopeSpoof (int x, int y)
{
    assert (x == y && y == 487);
}

void GlobalScope ()
{
    void bar () { GlobalScopeSpoof (487, 487); }
    bar ();
}

class TestClass
{
    int x = 6400;

    void foo ()
    {
       void bar () { assert (x == 6400); }
       bar ();
    }
}

void test12()
{
    SimpleNestedFunction ();
    AccessParentScope ();
    CrossNestedScope ();
    GlobalScope ();
    (new TestClass).foo ();
}


/*******************************************/

void test13()
{
    struct Abc
    {
	int x = 3;
	int y = 4;
    }

    Abc a;

    assert(a.x == 3 && a.y == 4);
}


/*******************************************/

void test14()
{
    struct Abc
    {
	int x = 3;
	int y = 4;

	int foo() { return y; }
    }

    Abc a;

    assert(a.foo() == 4);
}


/*******************************************/

void test15()
{
    static int z = 5;

    struct Abc
    {
	int x = 3;
	int y = 4;

	int foo() { return y + z; }
    }

    Abc a;

    assert(a.foo() == 9);
}


/*******************************************/

void test16()
{
    static int z = 5;

    static class Abc
    {
	int x = 3;
	int y = 4;

	int foo() { return y + z; }
    }

    Abc a = new Abc();

    assert(a.foo() == 9);
}


/*******************************************/

void test17()
{
    int function(int x) fp;

    fp = function int(int y) { return y + 3; };
    assert(fp(7) == 10);
}

/*******************************************/

void test18()
{
    static int a = 3;
    int function(int x) fp;

    fp = function int(int y) { return y + a; };
    assert(fp(7) == 10);
}

/*******************************************/

void test19()
{
    int a = 3;

    int delegate(int x) fp;

    fp = delegate int(int y) { return y + a; };
    assert(fp(7) == 10);
}


/*******************************************/

class Collection20
{
    int[3] array;

    void opApply(void delegate(int) fp)
    {
	for (int i = 0; i < array.length; i++)
	    fp(array[i]);
    }
}

int func20(Collection20 c)
{
    int max = int.min;

    c.opApply(delegate(int i) { if (i > max) max = i; });
    return max;
}

void test20()
{
    Collection20 c = new Collection20();

    c.array[0] = 7;
    c.array[1] = 26;
    c.array[2] = 25;

    int m = func20(c);
    assert(m == 26);
}


/*******************************************/

int bar21(int a)
{
    int c = 3;

    int foo(int b)
    {
	b += c;		// 4 is added to b
	c++;		// bar.c is now 5
	return b + c;	// 12 is returned
    }
    c = 4;
    int i = foo(a);	// i is set to 12
    return i + c;	// returns 17
}

void test21()
{
    int i = bar21(3);	// i is assigned 17
    assert(i == 17);
}

/*******************************************/

void foo22(void delegate() baz)
{
  baz();
}

void bar22(int i)
{
  int j = 14;
  printf("%d,%d\n",i,j);

  void fred()
  {
    printf("%d,%d\n",i,j);
    assert(i == 12 && j == 14);
  }

  fred();
  foo22(&fred);
}

void test22()
{
  bar22(12);
}


/*******************************************/

void frelled(void delegate() baz)
{
  baz();
}

class Foo23
{
  void bar(int i)
  {
    int j = 14;
    printf("%d,%d\n",i,j);

    void fred()
    {
	printf("%d,%d\n",i,j);
	assert(i == 12);
	assert(j == 14);
    }

    frelled(&fred);
  }
}

void test23()
{
  Foo23 f = new Foo23();
  
  f.bar(12);
}


/*******************************************/

void delegate () function (int x) store24;

void delegate () zoom24(int x)
{
   return delegate void () { };
}

void test24()
{
   store24 = &zoom24;
   store24 (1) ();
}


/*******************************************/

void test25()
{
    delegate() { printf("stop the insanity!\n"); }();
    delegate() { printf("stop the insanity! 2\n"); }();
}

/*******************************************/

alias bool delegate(int) callback26;


bool foo26(callback26 a)
{
    
  return a(12);
}

class Bar26
{
  
  int func(int v)
  {
    printf("func(v=%d)\n", v);
    foo26(delegate bool(int a)
	{
	    printf("%d %d\n",a,v); return true;
	    assert(a == 12);
	    assert(v == 15);
	    assert(0);
	} );
    
    return v;
  }
}


void test26()
{
  Bar26 b = new Bar26();
  
  b.func(15);
}


/*******************************************/

class A27
{
    uint myFunc()
    {
	uint myInt = 13;
	uint mySubFunc()
	{
	    return myInt;
	}
	return mySubFunc();
    }
}

void test27()
{
    A27 myInstance = new A27;
    int i = myInstance.myFunc();
    printf("%d\n", i);
    assert(i == 13);
}


/*******************************************/

void Foo28(void delegate() call)
{
    call();
}

class Bar28
{
    int func()
    {
	int count = 0;

	Foo28(delegate void() { ++count; } );
	return count;
    }
}

void test28()
{
    Bar28 b = new Bar28();
    int i = b.func();
    assert(i == 1);
}


/*******************************************/

class Foo29 
{
  void Func(void delegate() call)
  {
    for(int i = 0; i < 10; ++i)
      call();
  }
}

class Bar29
{
    int Func()
    {
	int count = 0;
	Foo29 ic = new Foo29();

	ic.Func(delegate void() { ++count; } );
	return count;
    }
}

void test29()
{
    Bar29 b = new Bar29();
    int i = b.Func();
    assert(i == 10);
}

/*******************************************/

struct Foo30
{
  int[] arr;
}

void Func30(Foo30 bar)
{
    void InnerFunc(int x, int y)
    {
      int a = bar.arr[y]; // Ok
    
      if(bar.arr[y]) // Access violation
      {
      }
    }
    
    InnerFunc(5,5);
}


void test30()
{
  Foo30 abc;

  abc.arr.length = 10;
  Func30(abc);
}


/*******************************************/

void call31(int d, void delegate(int d) f)
{
    assert(d == 100 || d == 200);
    printf("d = %d\n", d);
    f(d);
}

void test31()
{
    call31(100, delegate void(int d1)
	{
	    printf("d1 = %d\n", d1);
	    assert(d1 == 100);
	    call31(200, delegate void(int d2)
		{
		    printf("d1 = %d\n", d1);
		    printf("d2 = %d\n", d2);
		    assert(d1 == 100);
		    assert(d2 == 200);
		});
	});
}


/*******************************************/

void call32(int d, void delegate(int d) f)
{
    assert(d == 100 || d == 200);
    printf("d = %d\n", d);
    f(d);
}

void test32()
{
    call32(100, delegate void(int d1)
	{
	    int a = 3;
	    int b = 4;
	    printf("d1 = %d, a = %d, b = %d\n", d1, a, b);
	    assert(a == 3);
	    assert(b == 4);
	    assert(d1 == 100);

	    call32(200, delegate void(int d2)
		{
		    printf("d1 = %d, a = %d\n", d1, a);
		    printf("d2 = %d, b = %d\n", d2, b);
		    assert(a == 3);
		    assert(b == 4);
		    assert(d1 == 100);
		    assert(d2 == 200);
		});
	});
}


/*******************************************/

void test33()
{
    extern (C) int Foo1(int a, int b, int c)
    {
	assert(a == 1);
	assert(b == 2);
	assert(c == 3);
	return 1;
    }

    extern (D) int Foo2(int a, int b, int c)
    {
	assert(a == 1);
	assert(b == 2);
	assert(c == 3);
	return 2;
    }

    extern (Windows) int Foo3(int a, int b, int c)
    {
	assert(a == 1);
	assert(b == 2);
	assert(c == 3);
	return 3;
    }

    extern (Pascal) int Foo4(int a, int b, int c)
    {
	assert(a == 1);
	assert(b == 2);
	assert(c == 3);
	return 4;
    }

    assert(Foo1(1, 2, 3) == 1);
    assert(Foo2(1, 2, 3) == 2);
    assert(Foo3(1, 2, 3) == 3);
    assert(Foo4(1, 2, 3) == 4);

    printf("test33 success\n");
}

/*******************************************/

class Foo34
{
    int x;

    class Bar
    {	int y;

	int delegate() getDelegate()
        {
	    assert(y == 8);
	    auto i = sayHello();
	    assert(i == 23);
            return &sayHello;
        }
    }
    Bar bar;

    int sayHello()
    {
	printf("Hello\n");
	assert(x == 47);
	return 23;
    }

    this()
    {
	x = 47;
        bar = new Bar();
	bar.y = 8;
    }
}

void test34()
{
    Foo34 foo = new Foo34();
    int delegate() saydg = foo.bar.getDelegate();
    printf("This should print Hello:\n");
    auto i = saydg();
    assert(i == 23);
}

/*******************************************/

class Foo35
{
    int x = 42;
    void bar()
    {
	int y = 43;
        new class Object
        {
            this()
	    {
		//writefln("x = %s", x);
		//writefln("y = %s", y);
		assert(x == 42);
		assert(y == 43);
	    }
        };
    }
}

void test35()
{
    Foo35 f = new Foo35();
    f.bar();
}

/*******************************************/

class Foo36
{
    int x = 42;
    this()
    {
	int y = 43;
        new class Object
        {
            this()
	    {
		//writefln("x = %s", x);
		//writefln("y = %s", y);
		assert(x == 42);
		assert(y == 43);
	    }
        };
    }
}

void test36()
{
    Foo36 f = new Foo36();
}

/*******************************************/

class Foo37
{
    int x = 42;
    void bar()
    {
	int y = 43;
	void abc()
	{
	    new class Object
	    {
		this()
		{
		    //writefln("x = %s", x);
		    //writefln("y = %s", y);
		    assert(x == 42);
		    assert(y == 43);
		}
	    };
	}

	abc();
    }
}

void test37()
{
    Foo37 f = new Foo37();
    f.bar();
}

/*******************************************/

void test38()
{
    int status = 3;

    int delegate() foo()
    {
	class C
	{
	    int dg()
	    {
		return ++status;
	    }
	}

	C c = new C();
	
	return &c.dg;
    }

    int delegate() bar = foo();

    if(status != 3)
    {
	    assert(0);
    }

    if(bar() != 4)
    {
	    assert(0);
    }

    if(status != 4)
    {
	    assert(0);
    }
}

/*******************************************/

void test39()
{
    int status;

    int delegate() foo()
    {
	return &(new class
	    {
		int dg()
		{
		    return ++status;
		}
	    }
	).dg;
    }

    int delegate() bar = foo();
    
    if(status != 0)
    {
	assert(0);
    }

    if(bar() != 1)
    {
	assert(0);
    }

    if(status != 1)
    {
	assert(0);
    }
}

/*******************************************/

interface I40
{
    void get( string s );
}

class C40
{
    int a = 4;

    void init()
    {
        I40 i = new class() I40
	{
            void get( string s )
	    {
                func();
            }
        };
	i.get("hello");
    }
    void func( ){ assert(a == 4); }
}

void test40()
{
    C40 c = new C40();
    c.init();
}

/*******************************************/

class C41
{   int a = 3;

    void init()
    {
	class N
	{
            void get()
	    {
                func();
            }
	}
	N n = new N();
	n.get();
    }
    void func()
    {
	assert(a == 3);
    }
}


void test41()
{
   C41 c = new C41();
   c.init();
}

/*******************************************/

class C42
{   int a = 3;

    void init()
    {
	class N
	{
	    void init()
	    {
		class M
		{
		    void get()
		    {
			func();
		    }
		}
		M m = new M();
		m.get();
	    }
	}
	N n = new N();
	n.init();
    }
    void func()
    {
	assert(a == 3);
    }
}

void test42()
{
   C42 c = new C42();
   c.init();
}


/*******************************************/

int foo43(alias X)() { return X; }

void test43()
{
    int x = 3;

    void bar()
    {
	int y = 4;
	assert(foo43!(x)() == 3);
	assert(foo43!(y)() == 4);
    }

    bar();

    assert(foo43!(x)() == 3);
}


/*******************************************/

class Comb
{
}

Comb Foo44(Comb delegate()[] c...)
{
    Comb ec = c[0]();
    printf("1ec = %p\n", ec);
    ec.toString();
    printf("2ec = %p\n", ec);
    return ec;
}

Comb c44;

static this()
{
    c44 = new Comb;
}

void test44()
{
    c44 = Foo44(Foo44(c44));
}

/*******************************************/

class Bar45
{
    void test()
    {
	a = 4;
	Inner i = new Inner;
	i.foo();
    }

    class Inner
    {
	void foo()
	{
	    assert(a == 4);
	    Inner i = new Inner;
	    i.bar();
	}

	void bar()
	{
	    assert(a == 4);
	}
    }
    int a;
}

void test45()
{
    Bar45 b = new Bar45;
    assert(b.a == 0);
    b.test();
}

/*******************************************/

class Adapter
{
    int a = 2;

    int func()
    {
	return 73;
    }
}

class Foo46
{
    int b = 7;

    class AnonAdapter : Adapter
    {	int aa = 8;

	this()
	{
	    assert(b == 7);
	    assert(aa == 8);
	}
    }

    void func()
    {
        Adapter a = cast( Adapter )( new AnonAdapter() );
	assert(a.func() == 73);
	assert(a.a == 2);
    }
}

void test46()
{
    Foo46 f = new Foo46();
    f.func();
}


/*******************************************/

void test47()
{
    void delegate() test =
	{
	    struct Foo {int x=3;}
	    Foo f;
	    assert(f.x == 3);
	};
    test();
}

/*******************************************/

struct Outer48
{
    class Inner
    {
	this(int i) { b = i; }
	int b;
    }

    int a = 6;

    void f()
    {
	int nested()
	{
	    auto x = new Inner(a);
	    return x.b + 1;
	}
	int i = nested();
	assert(i == 7);
    }
}


void test48()
{
    Outer48 s;
    s.f();
}

/*******************************************/

void test49()
{
    int j = 10;
    void mainlocal(int x)
    {
	printf("mainlocal: j = %d, x = %d\n", j, x);
	assert(j == 10);
	assert(x == 1);
    }

    void fun2()
    {   int k = 20;
	void fun2local(int x)
	{
	    printf("fun2local: k = %d, x = %d\n", k, x);
	    assert(j == 10);
	    assert(k == 20);
	    assert(x == 2);
	}

	void fun1()
	{
	    mainlocal(1);
	    fun2local(2);
	}

	fun1();
    }

    fun2();
} 

/*******************************************/

void funa50(alias pred1, alias pred2)()
{
    pred1(1);
    pred2(2);
}

void funb50(alias pred1)()
{   int k = 20;
    void funb50local(int x)
    {
	printf("funb50local: k = %d, x = %d\n", k, x);
	assert(k == 20);
	assert(x == 2);
    }
    funa50!(pred1, funb50local)();
}

void test50()
{
    int j = 10;
    void mainlocal(int x)
    {
	printf("mainlocal: j = %d, x = %d\n", j, x);
	assert(j == 10);
	assert(x == 1);
    }
    funb50!(mainlocal)();
} 

/*******************************************/

void funa51(alias pred1, alias pred2)()
{
    pred1(2);
    pred2(1);
}

void funb51(alias pred1)()
{   int k = 20;
    void funb51local(int x)
    {
	printf("funb51local: k = %d, x = %d\n", k, x);
	assert(k == 20);
	assert(x == 2);
    }
    funa51!(funb51local, pred1)();
}

void test51()
{
    int j = 10;
    void mainlocal(int x)
    {
	printf("mainlocal: j = %d, x = %d\n", j, x);
	assert(j == 10);
	assert(x == 1);
    }
    funb51!(mainlocal)();
} 

/*******************************************/

C52 c52;

class C52
{
    int index = 7;
    void test1(){
        printf( "this = %p, index = %d\n", this, index );
	assert(index == 7);
	assert(this == c52);
    }
    void test()
    {
        class N
	{
            void callI()
	    {
		printf("test1\n");
                test1();
		printf("test2\n");
                if (index is -1)
		{   // Access to the outer-super-field triggers the bug
		    printf("test3\n");
                }
            }
        }
	auto i = new N();
        i.callI();
    }
}

void test52()
{
    auto c = new C52;
    printf("c = %p\n", c);
    c52 = c;
    c.test();
}

/*******************************************/

void foo53(int i)
{
    struct SS
    {
	int x,y;
	int bar() { return x + i + 1; }
    }
    SS s;
    s.x = 3;
    assert(s.bar() == 11);
}

void test53()
{
    foo53(7);
}

/*******************************************/

void test54()
{
    int x = 40;
    int fun(int i) { return x + i; }

    struct A
    {
	int bar(int i) { return fun(i); }
    }

    A makeA()
    {
	// A a;	return a;
	return A();
    }

    A makeA2()
    {
	 A a;	return a;
	//return A();
    }

    A a = makeA();
    assert(a.bar(2) == 42);

    A b = makeA2();
    assert(b.bar(3) == 43);

    auto c = new A;
    assert(c.bar(4) == 44);
}
/*******************************************/

void test55()
{
    int localvar = 7;

    int inner(int delegate(ref int) dg) {
        int k = localvar;
        return 0;
    }

    int a = localvar * localvar; // This modifies the EAX register

    foreach (entry; &inner)
    {
    }
}

/*******************************************/

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
    test14();
    test15();
    test16();
    test17();
    test18();
    test19();
    test20();
    test21();
    test22();
    test23();
    test24();
    test25();
    test26();
    test27();
    test28();
    test29();
    test30();
    test31();
    test32();
    test33();
    test34();
    test35();
    test36();
    test37();
    test38();
    test39();
    test40();
    test41();
    test42();
    test43();
    test44();
    test45();
    test46();
    test47();
    test48();
    test49();
    test50();
    test51();
    test52();
    test53();
    test54();
    test55();

    printf("Success\n");
    return 0;
}

