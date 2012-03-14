// PERMUTE_ARGS: -inline -g -O

extern(C) int printf(const char*, ...);

/*******************************************/

class A
{
     int x = 7;

     int foo(int i)
     in
     {
	printf("A.foo.in %d\n", i);
	assert(i == 2);
	assert(x == 7);
	printf("A.foo.in pass\n");
     }
     out (result)
     {
	assert(result & 1);
	assert(x == 7);
     }
     body
     {
	return i;
     }
}

class B : A
{
     override int foo(int i)
     in
     {
	float f;
	printf("B.foo.in %d\n", i);
	assert(i == 4);
	assert(x == 7);
	f = f + i;
     }
     out (result)
     {
	assert(result < 8);
	assert(x == 7);
     }
     body
     {
	return i - 1;
     }
}

void test1()
{
    auto b = new B();
    b.foo(2);
    b.foo(4);
}

/*******************************************/

class A2
{
     int x = 7;

     int foo(int i)
     in
     {
	printf("A2.foo.in %d\n", i);
	assert(i == 2);
	assert(x == 7);
	printf("A2.foo.in pass\n");
     }
     out (result)
     {
	assert(result & 1);
	assert(x == 7);
     }
     body
     {
	return i;
     }
}

class B2 : A2
{
     override int foo(int i)
     in
     {
	float f;
	printf("B2.foo.in %d\n", i);
	assert(i == 4);
	assert(x == 7);
	f = f + i;
     }
     out (result)
     {
	assert(result < 8);
	assert(x == 7);
     }
     body
     {
	return i - 1;
     }
}

class C : B2
{
     override int foo(int i)
     in
     {
	float f;
	printf("C.foo.in %d\n", i);
	assert(i == 6);
	assert(x == 7);
	f = f + i;
     }
     out (result)
     {
	assert(result == 1 || result == 3 || result == 5);
	assert(x == 7);
     }
     body
     {
	return i - 1;
     }
}

void test2()
{
    auto c = new C();
    c.foo(2);
    c.foo(4);
    c.foo(6);
}

/*******************************************/

void fun(int x)
in {
    if (x < 0) throw new Exception("a");
}
body {
}

void test3()
{
    fun(1);
}

/*******************************************/

interface Stack {
   int pop()
//   in { printf("pop.in\n"); }
   out(result) {
	printf("pop.out\n");
	assert(result == 3);
   }
}

class CC : Stack
{
    int pop()
    //out (result) { printf("CC.pop.out\n"); } body
    {
	printf("CC.pop.in\n");
	return 3;
    }
}

void test4()
{
    auto cc = new CC();
    cc.pop();
}

/*******************************************/

int mul100(int n)
out(result)
{
    assert(result == 500);
}
body
{
    return n * 100;
}

void test5()
{
    mul100(5);
}

/*******************************************/
// 3273

// original case
struct Bug3273
{
    ~this() {}
    invariant() {}
}

// simplest case
ref int func3273()
out(r)
{
	// Regression check of issue 3390
	static assert(!__traits(compiles, r = 1));
}
body
{
	static int dummy;
	return dummy;
}

void test6()
{
	func3273() = 1;
	assert(func3273() == 1);
}

/*******************************************/

/+
// http://d.puremagic.com/issues/show_bug.cgi?id=3722

class Bug3722A
{
    void fun() {}
}
class Bug3722B : Bug3722A
{
    override void fun() in { assert(false); } body {}
}

void test6()
{
    auto x = new Bug3722B();
    x.fun();
}
+/

/*******************************************/
// 7218

void test7218()
{
    size_t foo()  in{}  out{}  body{ return 0; } // OK
    size_t bar()  in{}/*out{}*/body{ return 0; } // OK
    size_t hoo()/*in{}*/out{}  body{ return 0; } // NG1
    size_t baz()/*in{}  out{}*/body{ return 0; } // NG2
}

/*******************************************/
// 7699

class P7699
{
    void f(int n) in {
        assert (n);
    } body { }
}
class D7699 : P7699
{
    void f(int n) in { } body { }
}

/*******************************************/

int main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
//    test6();
    test7218();

    printf("Success\n");
    return 0;
}
