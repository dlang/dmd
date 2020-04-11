/*
TEST_OUTPUT:
---
Object
---
*/

module test34;

import core.stdc.stdio;
import core.exception;


/************************************************/

void test2()
{
  assert( [2,3]!=[2,4] );
  assert( [3,2]!=[4,2] );
  assert( !([2,3]==[2,4]) );
  assert( ([2,3]==[2,3]) );
}

/************************************************/

class ExOuter
{
    class ExInner
    {
        this()
        {
            typeof(this.outer) X;
            static assert(is(typeof(X) == ExOuter));
        }
    }
}

void test4()
{
}

/************************************************/

int status5;

struct MyStruct5
{
}

void rec5(int i, MyStruct5 s)
{
    if( i > 0 )
    {
        status5++;
        rec5(i-1, s);
    }
}

void test5()
{
    assert(status5==0);
    MyStruct5 st;
    rec5(1030, st);
    assert(status5==1030);
}

/************************************************/

class C6
{
    const int a;

    this()
    {
        a = 3;
    }

    this(int x)
    {
        this();
    }
}

void test6()
{
}

/************************************************/

struct Foo8 { }

enum Enum { RED }

//typedef int myint;

alias int myalias;

void test8()
{
/+
    assert((1+2).stringof == "1 + 2");
    assert(Foo8.stringof == "Foo8");
    assert(test.Foo8.stringof == "test.Foo8");
    assert(int.stringof == "int");
    assert((int*[5][]).stringof == "int*[5][]");
    assert(Enum.RED.stringof == "Enum.RED");
    assert(test.myint.stringof == "test.myint");
    assert(myalias.stringof == "myalias");
    assert((5).stringof == "5");
    assert(typeof(5).stringof == "typeof(5)");
+/
}

/************************************************/

/+
class Base9 {
    public void fnc(){
    }
}

class Foo9 : Base9 {
    alias Base9.fnc fnc;
    public void fnc(){
    }
    static this(){
        alias void function() T;
        T ptr = & fnc;
    }
}
+/

void test9()
{
}

/************************************************/

bool isalnum(dchar c) { return c>='0' && c >= '9'; }

char[] toHtmlFilename(char[] fname)
{
    foreach (ref c; fname)
    {
        if (!isalnum(c) && c != '.' && c != '-')
            c = '_';
    }
    return fname;
}

void test10()
{
}

/************************************************/

template Foo12(T: T[U], U)
{
    alias int Foo12;
}

void test12()
{
    Foo12!(int[long]) x;
    assert(is(typeof(x) == int));
}

/************************************************/

class C13
{
    int a = 4;
    this()
    {
        printf("C13.this()\n");
        assert(a == 4);
        a = 5;
    }
}

void test13()
{
    C13 c = cast(C13)Object.factory("test34.C13");
    assert(c.a == 5);
    Object o = Object.factory("test35.C13");
    assert(o is null);
}

/************************************************/

class Base15 {
        int func(int a) { return 1; }
}


class Foo15 : Base15 {
        alias Base15.func func;
}


class Bar15 : Foo15 {
        alias Foo15.func func;
        int func(string a) { return 2; }
}

void test15()
{
    Bar15 b = new Bar15();
    assert(b.func("hello") == 2);
    assert(b.func(5) == 1);
}

/************************************************/

struct S17(T)
{
    struct iterator {}
}

int insert17(T) (S17!(T) lst, S17!(T).iterator i)
{
    return 3;
}

void test17()
{
    S17!(int) a;
    S17!(int).iterator i;
    auto x = insert17(a, i);
    assert(x == 3);
}

/************************************************/

void test18()
{
    real t = 0.;
    for(int i=0; i<10; i++)
    {
        t += 1.;
        real r =  (2*t);
        printf("%Lg  %Lg  %Lg\n", t, r, 2*t);
        assert(2*t == (i+1)*2);
    }
}

/************************************************/

void test19()
{
    char c = '3';
    void[] ca = cast(void[])[c];
    char[] x = cast(char[])ca;
    assert(x[0] == '3');
}

/************************************************/

enum type20
{
    a,
    b,
}

class myclass20
{
    template XX(uint a, uint c)
    {
        static uint XX(){ return (a*256+c);}
    }
    void testcase()
    {
        switch (cast(uint)type20.a)
        {
            case XX!(cast(uint)type20.a,cast(uint)type20.b)():
                break;
            default: assert(0);
        }
    }
}

void test20()
{
}

/************************************************/

struct S21
{
    alias int Foo;
    int x;
}

void test21()
{
    S21 s;
    typeof(s).Foo j;
    assert(is(typeof(j) == int));
}

/************************************************/

void test22()
{
    auto i = 3, j = 4;
    assert(is(typeof(i) == int));
    assert(is(typeof(j) == int));
}

/************************************************/

static m23 = 5, n23 = 6;

void test23()
{
    auto i = 3, j = 4;
    assert(is(typeof(i) == int));
    assert(is(typeof(j) == int));
    assert(is(typeof(m23) == int));
    assert(is(typeof(n23) == int));
}

/************************************************/

const int a24 = 0;
const int foo24 = 4;
const int[1] bar24 = [foo24 * 2];
const int zap24 = (1 << bar24[a24]);

void test24()
{
    assert(zap24 == 256);
}

/************************************************/

struct List25(T) {  }
struct CircularQueue25(T) {  }

void front25(T)(ref List25!(T) list) {  }
void front25(T)(ref CircularQueue25!(T) queue) {  }

void test25()
{
    List25!(int) x;
    front25(x);
}

/************************************************/

struct Foo26
{
    const string x;
}

static Foo26 foo26 = {"something"};

void test26()
{
    assert(foo26.x == "something");
}

/************************************************/

template Mang(alias F)
{
    class G { }
    alias void function (G ) H;
    const string mangledname = H.mangleof;
}

template moo(alias A)
{
    pragma(msg,"   ");
    const string a = Mang!(A).mangledname;
    pragma(msg,"   ");
    static assert(Mang!(A).mangledname == a); // FAILS !!!
    pragma(msg,"   ");
}

void test27()
{
    int q;
    string b = moo!(q).a;
}

/************************************************/

struct Color
{
    static void fromRgb(uint rgb)
    {
    }

    static void fromRgb(ubyte alpha, uint rgb)
    {
    }
}

void test28()
{
    Color.fromRgb(0);
    Color.fromRgb(cast(uint)0);
}

/************************************************/

void test29()
{
  const char[] t="abcd";
  const ubyte[] t2=cast(ubyte[])t;
  const char[] t3=['a','b','c','d'];
  const ubyte[] t4=cast(ubyte[])t3;
  assert(t4[1] == 'b');
}

/************************************************/

void test30()
{
  const char[] test = "" ~ 'a' ~ 'b' ~ 'c';
  char[] test2 = (cast(char[])null)~'a'~'b'~'c';
  const char[] test3 = (cast(char[])null)~'a'~'b'~'c';
  char[] test4 = (cast(char[])[])~'a'~'b'~'c';
  const char[] test5 = (cast(char[])[])~'a'~'b'~'c';
  const char[] test6 = null;
  const char[] test7 = test6~'a'~'b'~'c';
}

/************************************************/

class C31
{
    synchronized invariant() { int x; }
}

void test31()
{
}

/************************************************/

ulong foo32()
{
        return cast(ulong) (cast(ulong) 1176576512 + cast(float) -2);
}

void test32()
{
        assert(foo32()==1176576510);
}

/************************************************/

class RangeCoder
{
    uint[258] cumCount; // 256 + end + total
    uint lower;
    uint upper;
    ulong range;

    this() {
        for (int i=0; i<cumCount.length; i++)
            cumCount[i] = i;
        lower = 0;
        upper = 0xffffffff;
        range = 0x100000000;
    }

    void encode(uint symbol) {
        uint total = cumCount[$ - 1];
        // "Error: Access Violation" in following line
        upper = lower + cast(uint)((cumCount[symbol+1] * range) / total) - 1;
        lower = lower + cast(uint)((cumCount[symbol]   * range) / total);
    }
}

void test33()
{
    RangeCoder rc = new RangeCoder();
    rc.encode(77);
}

/************************************************/

void foo35()
{
    uint a;
    uint b;
    uint c;
    extern (Windows) int function(int i, int j, int k) xxx;

    a = 1;
    b = 2;
    c = 3;

    xxx = cast(typeof(xxx))(a + b);
    throw new Exception("xxx");
    xxx( 4, 5, 6 );
}

void test35()
{
}

/************************************************/

void test36()
{
    int* p = void, c = void;
}

/************************************************/

void test37()
{
    synchronized
    {
        synchronized
        {
            printf("Hello world!\n");
        }
    }
}

/************************************************/

struct Rect {
    int left, top, right, bottom;
}

void test38()
{
    print38(sizeTest(false));
    print38(sizeTest(true));
    print38(defaultRect);
}

static Rect sizeTest(bool empty) {
    if (empty) {
        Rect result;
        return result;
        //return Rect.init;
    } else {
        return defaultRect;
        /+Rect result = defaultRect;
        return result;+/
    }
}

void print38(Rect r) {
    printf("(%d, %d)-(%d, %d)\n", r.left, r.top, r.right, r.bottom);
    assert(r.left == 0);
    assert(r.right == 0);
    assert(r.top == 0);
    assert(r.bottom == 0);
}

Rect defaultRect() {
    return Rect.init;
}

/************************************************/

void test41()
{
}

/************************************************/

enum Enum42 {
        A = 1
}

void test42() {
        Enum42[] enums = new Enum42[1];
        assert(enums[0] == Enum42.A);
}


/************************************************/

struct A43 {}

struct B43(L) {
  A43 l;
}

void test43()
{
  A43 a;
  auto b = B43!(A43)(a);
}

/************************************************/

void test44()
{
    int[ const char[] ] a = ["abc":3, "def":4];
}

/************************************************/

void test45()
{
    //char[3][] a = ["abc", "def"];
    //writefln(a);
    //char[][2] b = ["abc", "def"];
    //writefln(b);
}

/************************************************/

struct bignum
{
    bool smaller()
    {
        if (true) return false;
        else      return false;
        assert(0);
    }

    void equal()
    {
        if (!smaller)
            return;
    }
}

void test46()
{
}

/************************************************/

static size_t myfind(string haystack, char needle) {
  foreach (i, c ; haystack) {
    if (c == needle) return i;
  }
  return size_t.max;
}

static size_t skip_digits(string s) {
  foreach (i, c ; s) {
    if (c < '0' || c > '9') return i;
  }
  return s.length;
}

static uint matoi(string s) {
  uint result = 0;
  foreach (c ; s) {
    if (c < '0' || c > '9') break;
    result = result * 10 + (c - '0');
  }
  return result;
}

enum { leading, skip, width, modifier, format, fmt_length, extra };

static string GetFormat(string s) {
  uint pos = 0;
  string result;
  // find the percent sign
  while (pos < s.length && s[pos] != '%') {
    ++pos;
  }
  const leading_chars = pos;
  result ~= cast(char) pos;
  if (pos < s.length) ++pos; // go right after the '%'
  // skip?
  if (pos < s.length && s[pos] == '*') {
    result ~= 1;
    ++pos;
  } else {
    result ~= 0;
  }
  // width?
  result ~= cast(char) matoi(s);
  pos += skip_digits(s[pos .. $]);
  // modifier?
  if (pos < s.length && myfind("hjlLqtz", s[pos]) != size_t.max) {
    // @@@@@@@@@@@@@@@@@@@@@@@@@@@@
    static if (true) {
      result ~= s[pos++];
    } else {
      result ~= s[pos];
      ++pos;
    }
    // @@@@@@@@@@@@@@@@@@@@@@@@@@@@
  } else {
    result ~= '\0';
  }
  return result;
}

void test47()
{
  static string test = GetFormat(" %*Lf");
  assert(test[modifier] == 'L', "`" ~ test[modifier] ~ "'");
}

/************************************************/

class B48() {}
class C48   {}

int foo48()(B48!()) { return 1; }
int foo48()(C48 c) { return 2; }

void test48()
{
    auto i = foo48(new B48!());
    assert(i == 1);

    i = foo48(new C48);
    assert(i == 2);
}

/************************************************/

struct S51
{
    int i = 3;
    void div() { assert(i == 3); }
}

void test51()
{
    S51().div();
}

/************************************************/

void test52()
{
    struct Foo {
        alias int Y;
    }
    with (Foo) {
         Y y;
    }
}

/************************************************/

class B55 {}
class D55 : B55 {}

template foo55(S, T : S) { }    // doesn't work

alias foo55!(B55, D55) bar55;

void test55()
{
}

/************************************************/

template t56() { alias Object t56; }
pragma(msg, t56!().stringof);

void test56()
{
}

/************************************************/

static this()
{
   printf("one\n");
}

static this()
{
   printf("two\n");
}

static ~this()
{
   printf("~two\n");
}

static ~this()
{
   printf("~one\n");
}


void test59()
{
}

/************************************************/

class C60
{
    extern (C++) int bar60(int i, int j, int k)
    {
        printf("this = %p\n", this);
        printf("i = %d\n", i);
        printf("j = %d\n", j);
        printf("k = %d\n", k);
        assert(i == 4);
        assert(j == 5);
        assert(k == 6);
        return 1;
    }
}


extern (C++)
        int foo60(int i, int j, int k)
{
    printf("i = %d\n", i);
    printf("j = %d\n", j);
    printf("k = %d\n", k);
    assert(i == 1);
    assert(j == 2);
    assert(k == 3);
    return 1;
}

void test60()
{
    foo60(1, 2, 3);

    C60 c = new C60();
    c.bar60(4, 5, 6);
}

/***************************************************/

template Foo61(alias a) {}

struct Bar61 {}
const Bar61 bar61 = {};

alias Foo61!(bar61) baz61;

void test61()
{
}

/************************************************/

T foo62(T)(lazy T value)
{
    return value;
}

void test62()
{
    foo62(new float[1]);
}

/************************************************/

void main()
{
    test2();
    test4();
    test5();
    test6();
    test8();
    test9();
    test10();
    test12();
    test13();
    test15();
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
    test35();
    test36();
    test37();
    test38();
    test41();
    test42();
    test43();
    test44();
    test45();
    test46();
    test47();
    test48();
    test51();
    test52();
    test55();
    test56();
    test59();
    test60();
    test61();
    test62();

    printf("Success\n");
}


