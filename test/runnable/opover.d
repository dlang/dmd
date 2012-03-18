
// Test operator overloading

import std.c.stdio;

/**************************************/

class A1
{
    int opAdd(int i) { return 7 + i; }
}

void test1()
{
    A1 a = new A1();
    int i;

    i = a + 3;
    assert(i == 10);

    i = 4 + a;
    assert(i == 11);
}

/**************************************/

class A2
{
    int opDiv(int i)   { return 9 + i; }
    int opDiv_r(int i) { return 17 + i; }
}

void test2()
{
    A2 a = new A2();
    int i;

    i = a / 3;
    assert(i == 12);

    i = 4 / a;
    assert(i == 21);
}

/**************************************/

class C1
{
}

class C2
{
    int opAdd(D1 d)   { return 1; }
    int opAdd(D2 d)   { return 2; }
    int opAdd(D3 d)   { return 3; }
    int opAdd(D4 d)   { return 4; }
}

class C3
{
    int opAdd_r(D1 d) { return 5; }
    int opAdd_r(D2 d) { return 6; }
    int opAdd_r(D3 d) { return 7; }
    int opAdd_r(D4 d) { return 8; }
}

class C4
{
    int opAdd(D1 d)   { return 9; }
    int opAdd(D2 d)   { return 10; }
    int opAdd(D3 d)   { return 11; }
    int opAdd(D4 d)   { return 12; }

    int opAdd_r(D1 d) { return 13; }
    int opAdd_r(D2 d) { return 14; }
    int opAdd_r(D3 d) { return 15; }
    int opAdd_r(D4 d) { return 16; }
}

class D1
{
}

class D2
{
    int opAdd(C1 c)   { return 17; }
    int opAdd(C2 d)   { return 18; }
    int opAdd(C3 d)   { return 19; }
    int opAdd(C4 d)   { return 20; }
}

class D3
{
    int opAdd_r(C1 d) { return 21; }
    int opAdd_r(C2 d) { return 22; }
    int opAdd_r(C3 d) { return 23; }
    int opAdd_r(C4 d) { return 24; }
}

class D4
{
    int opAdd(C1 d)   { return 25; }
    int opAdd(C2 d)   { return 26; }
    int opAdd(C3 d)   { return 27; }
    int opAdd(C4 d)   { return 28; }

    int opAdd_r(C1 d) { return 29; }
    int opAdd_r(C2 d) { return 30; }
    int opAdd_r(C3 d) { return 31; }
    int opAdd_r(C4 d) { return 32; }
}



void test3()
{
    C1 c1 = new C1();
    C2 c2 = new C2();
    C3 c3 = new C3();
    C4 c4 = new C4();
    D1 d1 = new D1();
    D2 d2 = new D2();
    D3 d3 = new D3();
    D4 d4 = new D4();

    int i;

  version (ADD_R)
  {
    //i = c1 + d1;    assert(i == );
    i = c1 + d2;    assert(i == 17);
    i = c1 + d3;    assert(i == 21);
    i = c1 + d4;    assert(i == 29);

    i = c2 + d1;    assert(i == 1);
    i = c2 + d2;    assert(i == 2);
    i = c2 + d3;    assert(i == 3);
    i = c2 + d4;    assert(i == 4);

    //i = c3 + d1;    assert(i == );
    i = c3 + d2;    assert(i == 19);
    i = c3 + d3;    assert(i == 23);
    i = c3 + d4;    assert(i == 31);

    i = c4 + d1;    assert(i == 9);
    i = c4 + d2;    assert(i == 10);
    i = c4 + d3;    assert(i == 11);
    i = c4 + d4;    assert(i == 12);

    //i = d1 + c1;    assert(i == );
    i = d1 + c2;    assert(i == 1);
    i = d1 + c3;    assert(i == 5);
    i = d1 + c4;    assert(i == 13);

    i = d2 + c1;    assert(i == 17);
    i = d2 + c2;    assert(i == 18);
    i = d2 + c3;    assert(i == 19);
    i = d2 + c4;    assert(i == 20);

    //i = d3 + c1;    assert(i == );
    i = d3 + c2;    assert(i == 3);
    i = d3 + c3;    assert(i == 7);
    i = d3 + c4;    assert(i == 15);

    i = d4 + c1;    assert(i == 25);
    i = d4 + c2;    assert(i == 26);
    i = d4 + c3;    assert(i == 27);
    i = d4 + c4;    assert(i == 28);
  }
  else
  {
    //i = c1 + d1;    assert(i == );
    i = c1 + d2;    assert(i == 17);
//    i = c1 + d3;    assert(i == 21);
    i = c1 + d4;    assert(i == 29);

    i = c2 + d1;    assert(i == 1);
    i = c2 + d2;    assert(i == 2);
//    i = c2 + d3;    assert(i == 3);
//    i = c2 + d4;    assert(i == 4);

    //i = c3 + d1;    assert(i == );
//    i = c3 + d2;    printf("i = %d\n", i); assert(i == 19);
//    i = c3 + d3;    assert(i == 23);
    i = c3 + d4;    assert(i == 31);

    i = c4 + d1;    assert(i == 9);
    i = c4 + d2;    assert(i == 10);
//    i = c4 + d3;    assert(i == 11);
//    i = c4 + d4;    assert(i == 12);

    //i = d1 + c1;    assert(i == );
    i = d1 + c2;    assert(i == 1);
//    i = d1 + c3;    assert(i == 5);
    i = d1 + c4;    assert(i == 13);

    i = d2 + c1;    assert(i == 17);
    i = d2 + c2;    assert(i == 18);
//    i = d2 + c3;    assert(i == 19);
//    i = d2 + c4;    assert(i == 20);

    //i = d3 + c1;    assert(i == );
//    i = d3 + c2;    assert(i == 3);
//    i = d3 + c3;    assert(i == 7);
    i = d3 + c4;    assert(i == 15);

    i = d4 + c1;    assert(i == 25);
    i = d4 + c2;    assert(i == 26);
//    i = d4 + c3;    assert(i == 27);
//    i = d4 + c4;    assert(i == 28);
  }
}

/**************************************/

struct Foo4
{
	int a;
	int opCmp(Foo4 b)
	{
	    return a < b.a;
	}
}

void test4()
{
   Foo4 a;
   Foo4 b;

   assert(a <= b);
}

/**************************************/

class A5
{
    int opNeg()     { return 10; }
    int opCom()     { return 11; }
    int opPostInc() { return 12; }
    int opPostDec() { return 13; }

    int opAdd(int j)     { return 14; }
    int opSub(int j)     { return 15; }
    int opSub_r(int j)   { return 16; }
    int opMul(int j)     { return 17; }
    int opDiv(int j)     { return 18; }
    int opDiv_r(int j)   { return 19; }
    int opMod(int j)     { return 20; }
    int opMod_r(int j)   { return 21; }
    int opAnd(int j)     { return 22; }
    int opOr(int j)      { return 23; }
    int opXor(int j)     { return 24; }
    int opShl(int j)     { return 25; }
    int opShl_r(int j)   { return 26; }
    int opShr(int j)     { return 27; }
    int opShr_r(int j)   { return 28; }
    int opUShr(int j)    { return 29; }
    int opUShr_r(int j)  { return 30; }
    int opCat(int j)     { return 31; }
    int opCat_r(int j)   { return 32; }
    int opEquals(int j)  { return 33; }
    int opCmp(int j)     { return 34; }
    int opAddAssign(int j)  { return 35; }
    int opSubAssign(int j)  { return 36; }
    int opMulAssign(int j)  { return 37; }
    int opDivAssign(int j)  { return 38; }
    int opModAssign(int j)  { return 39; }
    int opAndAssign(int j)  { return 40; }
    int opOrAssign(int j)   { return 41; }
    int opXorAssign(int j)  { return 42; }
    int opShlAssign(int j)  { return 43; }
    int opShrAssign(int j)  { return 44; }
    int opUShrAssign(int j) { return 45; }
    int opCatAssign(int j)  { return 46; }
}

void test5()
{
    A5 a = new A5();
    int i;

    i = -a;
    assert(i == 10);

    i = ~a;
    assert(i == 11);

    i = a++;
    assert(i == 12);

    i = a--;
    assert(i == 13);

    i = a + 1;
    assert(i == 14);

    i = a - 1;
    assert(i == 15);

    i = 1 - a;
    assert(i == 16);

    i = a * 1;
    assert(i == 17);

    i = a / 1;
    assert(i == 18);

    i = 1 / a;
    assert(i == 19);

    i = a % 1;
    assert(i == 20);

    i = 1 % a;
    assert(i == 21);

    i = a & 1;
    assert(i == 22);

    i = a | 1;
    assert(i == 23);

    i = a ^ 1;
    assert(i == 24);

    i = a << 1;
    assert(i == 25);

    i = 1 << a;
    assert(i == 26);

    i = a >> 1;
    assert(i == 27);

    i = 1 >> a;
    assert(i == 28);

    i = a >>> 1;
    assert(i == 29);

    i = 1 >>> a;
    assert(i == 30);

    i = a ~ 1;
    assert(i == 31);

    i = 1 ~ a;
    assert(i == 32);

    i = a == 1;
    assert(i == 33);
    i = 1 == a;
    assert(i == 33);
    i = a != 1;
    assert(i == 0);
    i = 1 != a;
    assert(i == 0);

    i = a < 1;
    assert(i == 0);
    i = a <= 1;
    assert(i == 0);
    i = a > 1;
    assert(i == 1);
    i = a >= 1;
    assert(i == 1);

    i = 1 < a;
printf("i = %d\n", i);
    assert(i == 1);
    i = 1 <= a;
    assert(i == 1);
    i = 1 > a;
    assert(i == 0);
    i = 1 >= a;
    assert(i == 0);

    i = a !<>= 1;
    assert(i == 0);
    i = a !<> 1;
    assert(i == 0);
    i = a <>= 1;
    assert(i == 1);
    i = a !>= 1;
    assert(i == 0);
    i = a !>= 1;
    assert(i == 0);
    i = a !< 1;
    assert(i == 1);
    i = a !<= 1;
    assert(i == 1);

    i = 1 !<>= a;
    assert(i == 0);
    i = 1 !<> a;
    assert(i == 0);
    i = 1 <>= a;
    assert(i == 1);
    i = 1 !>= a;
    assert(i == 1);
    i = 1 !>= a;
    assert(i == 1);
    i = 1 !< a;
    assert(i == 0);
    i = 1 !<= a;
    assert(i == 0);

    i = (a += 1);
    assert(i == 35);
    i = ++a;
    assert(i == 35);

    i = (a -= 1);
    assert(i == 36);
    i = --a;
    assert(i == 36);

    i = (a *= 1);
    assert(i == 37);

    i = (a /= 1);
    assert(i == 38);

    i = (a %= 1);
    assert(i == 39);

    i = (a &= 1);
    assert(i == 40);

    i = (a |= 1);
    assert(i == 41);

    i = (a ^= 1);
    assert(i == 42);

    i = (a <<= 1);
    assert(i == 43);

    i = (a >>= 1);
    assert(i == 44);

    i = (a >>>= 1);
    assert(i == 45);

    i = (a ~= 1);
    assert(i == 46);
}

/*********************************/

struct A6
{
    int opNeg()     { return 10; }
    int opCom()     { return 11; }
    int opPostInc() { return 12; }
    int opPostDec() { return 13; }

    int opAdd(int j)     { return 14; }
    int opSub(int j)     { return 15; }
    int opSub_r(int j)   { return 16; }
    int opMul(int j)     { return 17; }
    int opDiv(int j)     { return 18; }
    int opDiv_r(int j)   { return 19; }
    int opMod(int j)     { return 20; }
    int opMod_r(int j)   { return 21; }
    int opAnd(int j)     { return 22; }
    int opOr(int j)      { return 23; }
    int opXor(int j)     { return 24; }
    int opShl(int j)     { return 25; }
    int opShl_r(int j)   { return 26; }
    int opShr(int j)     { return 27; }
    int opShr_r(int j)   { return 28; }
    int opUShr(int j)    { return 29; }
    int opUShr_r(int j)  { return 30; }
    int opCat(int j)     { return 31; }
    int opCat_r(int j)   { return 32; }
    int opEquals(int j)      { return 33; }
    const bool opEquals(const ref A6)      { return false; }
    int opCmp(int j)     { return 34; }
    int opAddAssign(int j)  { return 35; }
    int opSubAssign(int j)  { return 36; }
    int opMulAssign(int j)  { return 37; }
    int opDivAssign(int j)  { return 38; }
    int opModAssign(int j)  { return 39; }
    int opAndAssign(int j)  { return 40; }
    int opOrAssign(int j)   { return 41; }
    int opXorAssign(int j)  { return 42; }
    int opShlAssign(int j)  { return 43; }
    int opShrAssign(int j)  { return 44; }
    int opUShrAssign(int j) { return 45; }
    int opCatAssign(int j)  { return 46; }
}

void test6()
{
    A6 a;
    int i;

    i = -a;
    assert(i == 10);

    i = ~a;
    assert(i == 11);

    i = a++;
    assert(i == 12);

    i = a--;
    assert(i == 13);

    i = a + 1;
    assert(i == 14);

    i = a - 1;
    assert(i == 15);

    i = 1 - a;
    assert(i == 16);

    i = a * 1;
    assert(i == 17);

    i = a / 1;
    assert(i == 18);

    i = 1 / a;
    assert(i == 19);

    i = a % 1;
    assert(i == 20);

    i = 1 % a;
    assert(i == 21);

    i = a & 1;
    assert(i == 22);

    i = a | 1;
    assert(i == 23);

    i = a ^ 1;
    assert(i == 24);

    i = a << 1;
    assert(i == 25);

    i = 1 << a;
    assert(i == 26);

    i = a >> 1;
    assert(i == 27);

    i = 1 >> a;
    assert(i == 28);

    i = a >>> 1;
    assert(i == 29);

    i = 1 >>> a;
    assert(i == 30);

    i = a ~ 1;
    assert(i == 31);

    i = 1 ~ a;
    assert(i == 32);

    i = a == 1;
    assert(i == 33);
    i = 1 == a;
    assert(i == 33);
    i = a != 1;
    assert(i == 0);
    i = 1 != a;
    assert(i == 0);

    i = a < 1;
    assert(i == 0);
    i = a <= 1;
    assert(i == 0);
    i = a > 1;
    assert(i == 1);
    i = a >= 1;
    assert(i == 1);

    i = 1 < a;
    assert(i == 1);
    i = 1 <= a;
    assert(i == 1);
    i = 1 > a;
    assert(i == 0);
    i = 1 >= a;
    assert(i == 0);

    i = a !<>= 1;
    assert(i == 0);
    i = a !<> 1;
    assert(i == 0);
    i = a <>= 1;
    assert(i == 1);
    i = a !>= 1;
    assert(i == 0);
    i = a !>= 1;
    assert(i == 0);
    i = a !< 1;
    assert(i == 1);
    i = a !<= 1;
    assert(i == 1);

    i = 1 !<>= a;
    assert(i == 0);
    i = 1 !<> a;
    assert(i == 0);
    i = 1 <>= a;
    assert(i == 1);
    i = 1 !>= a;
    assert(i == 1);
    i = 1 !>= a;
    assert(i == 1);
    i = 1 !< a;
    assert(i == 0);
    i = 1 !<= a;
    assert(i == 0);

    i = (a += 1);
    assert(i == 35);
    i = ++a;
    assert(i == 35);

    i = (a -= 1);
    assert(i == 36);
    i = --a;
    assert(i == 36);

    i = (a *= 1);
    assert(i == 37);

    i = (a /= 1);
    assert(i == 38);

    i = (a %= 1);
    assert(i == 39);

    i = (a &= 1);
    assert(i == 40);

    i = (a |= 1);
    assert(i == 41);

    i = (a ^= 1);
    assert(i == 42);

    i = (a <<= 1);
    assert(i == 43);

    i = (a >>= 1);
    assert(i == 44);

    i = (a >>>= 1);
    assert(i == 45);

    i = (a ~= 1);
    assert(i == 46);
}


/**************************************/

struct Foo7
{
    int opSlice() { return 7; }
    int opSlice(int i, int j) { return i * (j + 1); }
}

void test7()
{
    Foo7 f;
    int i;

    i = f[];
    assert(i == 7);
    i = f[3..4];
    assert(i == 15);
}

/**************************************/

interface IWriter
{
        int opShl (string i);
        int opShl (int i);
}

class Writer : IWriter
{
        int opShl (string i)
        {
		printf("Writer.opShl(char[])\n");
                return 1;
        }

        int opShl (int i)
        {
		printf("Writer.opShl(int)\n");
                return 2;
        }
}

class BinaryWriter : Writer
{
	alias Writer.opShl opShl;

        override int opShl (int i)
        {
		printf("BinaryWriter.opShl(int)\n");
                return 3;
        }
}

void test8()
{
        BinaryWriter bw = new BinaryWriter();
	int i;

        i = bw << "test";
	assert(i == 1);
        i = bw << 1;
	assert(i == 3);
}

/**************************************/

struct A9
{
    int opCast() { return 28; }
}

void test9()
{
    A9 a;

    long i = cast(long)a;
    assert(i == 28);
}

/**************************************/

class A10
{
    int opAdd(int i) { return i + 1; }
}

class B10
{
    int opAdd_r(A10 a) { return 3; }
}

void test10()
{
    int i;
    A10 a = new A10();

    i = a + 1;
    printf("a + 1 = %d\n", i);
    assert(i == 2);

    i = 1 + a;
    printf("1 + a = %d\n", i);
    assert(i == 2);

    B10 b = new B10();
    i = a + b;
    printf("a + b = %d\n", i);
    assert(i == 3);

    i = b + a;
    printf("b + a = %d\n", i);
    assert(i == 3);

//    i = b + 3;
}

/**************************************/

class A11
{
    int opIndex(int i) { return i; }
    int opIndexAssign(int value, int i) { return value * 10 + i; }
}

void test11()
{
    int i;
    A11 a = new A11();

    i = a[5];
    assert(i == 5);
    i = (a[4] = 6);
    printf("i = %d\n", i);
    assert(i == 64);
}

/**************************************/

class A12
{
    int opIndex(int i1, int i2) { return i1 * 10 + i2; }
    int opIndexAssign(int value, int i1, int i2) { return value * 100 + i1 * 10 + i2; }
}


void test12()
{
   A12 a = new A12();
   int i;

   printf("%d\n", a[1, 2]);
   assert(a[1, 2] == 12);

   i = (a[3, 4] = 5);
   printf("%d\n", i);
   assert(i == 534);
}

/**************************************/

class A13
{
 A13 opShl(int x)
 {
    printf("A::opShl(int %d)\n", x);
    printf("%d",x);
    return this;
 }
 A13 opShl(string x)
 {
    printf("A::opShl(char[])\n");
    printf("%.*s", x.length, x.ptr);
    return this;
 }
}

class B13
{
 A13 opShl_r(A13 a)
 {
    printf("B::opShl_r(A)\n");
    return a;
 }
}

void test13()
{
    A13 a = new A13();
    a << 4 << " " << 12 << "\n";

    B13 b = new B13();
    a << b;
}


/**************************************/

class Foo14
{   int a;

    int opIn(int x)
    {
	return a + x;
    }
}

void test14()
{
    auto f = new Foo14;
    f.a = 3;
    auto i = f in 7;
    assert(i == 10);
}

/**************************************/

// 3983

struct Fug
{
    bool opEquals(ref const Fug y) const {
        return false;
    }
}

struct Fig
{
   Fug f;
   bool opEquals(Tdummy=void)(ref const Fig y) const {
      return false;
   }

   bool opEquals(T: int)(T y) const {
      return false;
   }
}

void test15()
{
  Fig fx, fy;
  if (fx==2) {}
}

/**************************************/

//void bug4953(T = void)(short x) {}
//static assert(is(typeof(bug4953(3))));

/**************************************/
// 4993

// reduced from the bug report
struct Bar4993
{
    void opIndexAssign(int value, size_t index) {}
}
@property auto bar4993()
{
    return Bar4993();
}
void test4993()
{
    bar4993[3] = 42;
}

/**************************************/

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
    test4993();

    printf("Success\n");
    return 0;
}
