
import std.stdio;

// Test function inlining

/************************************/

int foo(int i)
{
    return i;
}

int bar()
{
    return foo(3) + 4;
}

void test1()
{
    printf("%d\n", bar());
    assert(bar() == 7);
}


/************************************/

struct Foo2
{
    int a,b,c,e,f,g;
}


int foo2(Foo2 f)
{
    f.b += 73;
    return f.b;
}

int bar2()
{
    Foo2 gg;

    gg.b = 6;
    return foo2(gg) + 4;
}

void test2()
{
    printf("%d\n", bar2());
    assert(bar2() == 83);
}


/************************************/

struct Foo3
{
	int bar() { return y + 3; }
	int y = 4;
}

void test3()
{
    Foo3 f;

    assert(f.bar() == 7);
}


/************************************/

void func(void function () v)
{
}

void test4()
{
   static void f1() { }
   
   func(&f1);
   //func(f1);  
} 


/************************************/

void foo5(ubyte[16] array)
{
    bar5(array.ptr);
}

void bar5(ubyte *array)
{
}

void abc5(ubyte[16] array)
{
    foo5(array);
}

void test5()
{
}

/************************************/

struct Struct
{
    real foo()
    {
	return 0;
    }

    void bar(out Struct Q)
    {
	if (foo() < 0)
	    Q = this; 
    }
}

void test6()
{
}

/************************************/

struct S7(T)
{
    immutable(T)[] s;
}

T foo7(T)(T t)
{
    enum S7!(T)[] i = [{"hello"},{"world"}];
    auto x = i[0].s;
    return t;
}

void test7()
{
    auto x = foo7('c');
}

/************************************/
// Bugzilla 4825

int a8() {
    int r;
    return r;
}

int b8() {
    return a8();
}

void test8() {
    void d() {
        auto e = b8();
    }
    static const int f = b8();
}

/************************************/
// 7261

struct AbstractTask
{
    ubyte taskStatus;
}

struct Task
{
    AbstractTask base;
    alias base this;

    void opAssign(Task rhs)
    {
    }

    ~this()
    {
        if (taskStatus != 3) { }
    }
}

/************************************/

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

    printf("Success\n");
    return 0;
}
