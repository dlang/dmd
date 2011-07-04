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
     int foo(int i)
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
     int foo(int i)
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
     int foo(int i)
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
