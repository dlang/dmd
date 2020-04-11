module test;

import core.stdc.stdio;
import core.vararg;


/*******************************************/

struct S1
{
    void* function(void*) fn;
}

template M1()
{
    S1 s;
}

void test1()
{
    S1 s2;
    mixin M1;
    assert(s.fn == null);
}

/*******************************************/

enum Qwert { yuiop }

int asdfg(Qwert hjkl) { return 1; }
int asdfg(uint zxcvb) { return 2; }

void test2()
{
    int nm = 2;

    assert(asdfg(nm) == 2);
    assert(asdfg(cast(int) nm) == 2);
    assert(asdfg(3) == 2);
    assert(asdfg(cast(int) 3) == 2);
    assert(asdfg(3L) == 2);
    assert(asdfg(cast(int) 3L) == 2);
    assert(asdfg(3 + 2) == 2);
    assert(asdfg(cast(int) (3 + 2)) == 2);
    assert(asdfg(nm + 2) == 2);
    assert(asdfg(cast(int) (nm + 2)) == 2);
    assert(asdfg(3 + nm) == 2);
    assert(asdfg(cast(int) (3 + nm)) == 2);

}

/*******************************************/

template Qwert3(string yuiop) {
    immutable string Qwert3 = cast(string)yuiop;
}

template Asdfg3(string yuiop) {
    immutable string Asdfg3 = cast(string)Qwert3!(cast(string)(cast(string)yuiop ~ cast(string)"hjkl"));
}

void test3()
{
    string zxcvb = Asdfg3!(null);
    assert(zxcvb == "hjkl");
    assert(zxcvb == "hjkl" ~ null);
}

/*******************************************/

template Qwert4(string yuiop)
{
    immutable string Qwert4 = cast(string)(yuiop ~ "asdfg" ~ yuiop);
}

void test4()
{
    string hjkl = Qwert4!(null);
    assert(hjkl == "asdfg");
}

/*******************************************/

void test6()
{
    struct Foo
    {
        void foo() { }
    }

    alias Foo Bar;

    Bar a;
    a.foo();
}

/*******************************************/

void test7()
{
    struct Foo
    {
        alias typeof(this) ThisType;
        alias typeof(this) ThatType;
    }

    assert(is(Foo.ThisType == Foo));
    assert(is(Foo.ThatType == Foo));
}

/*******************************************/

cdouble y9;

cdouble f9(cdouble x)
{
    return (y9 = x);
}

void test9()
{
    f9(1.0+2.0i);
    assert(y9 == 1.0+2.0i);
}

/*******************************************/

class CBase10
{
    this() { }
}

void foo10( CBase10 l )
{
}

void test10()
{
    if (1)
    {
        foo10( new class() CBase10
               {
                    this() { super(); }
               }
             );
    }
    return;
}

/*******************************************/

struct Foo11
{
    static
        int func(T)(T a) { assert(a == 1); return 0; }
}

void test11()
{
        auto a = Foo11.init.func(1);
        a = Foo11.init.func!(int)(1);
        a = Foo11.func(1);
        a = Foo11.func!(int)(1);
}

/*******************************************/

void test12()
{
    class ExceptioN { }

    class ExceptioX { }

    static assert(ExceptioN.mangleof[0 ..$-1] == ExceptioX.mangleof[0 .. $-1]);
}

/*******************************************/

template check( char ch1, char ch2)
{
    const bool check = ch1 == ch2;
}

void test13()
{
        const char[] s = "123+456" ;
        assert(check!( '+', s[3] ) == true);
}

/*******************************************/

void test14()
{
    static const char[] test=['a','b','c','d'];
    static assert(test==['a','b','c','d']);
    static assert(['a','b','c','d']== test);
}

/*******************************************/

void func15(...)
in {
    printf("Arguments len = %d\n", cast(int)_arguments.length);
    assert(_arguments.length == 2);
}
do {

}

void test15()
{
    func15(1, 2);
}

/*******************************************/

void test17()
{
    void delegate() y = { };
    y();
}

/*******************************************/

abstract class Pen { int foo(); }

class Penfold : Pen {
    override int foo() { return 1; }
}

class Pinky : Pen {
    override int foo() { return 2; }
}

class Printer {
    void vprint(Pen obj) {
        assert(obj.foo() == 1 || obj.foo() == 2);
    }

    C print(C)(C obj) {
        assert(obj.foo() == 1 || obj.foo() == 2);
        return obj;
    }

}

void test18()
{
    Printer p = new Printer;
    p.print(new Pinky);
    p.print(new Penfold);
    with (p)
    {
        vprint(new Pinky);
        vprint(new Penfold);

        print!(Pinky)(new Pinky);
        print!(Penfold)(new Penfold);

        p.print(new Pinky);
        p.print(new Penfold);

        print(new Pinky);
        print(new Penfold);
    }
}

/*******************************************/


class A19
{
    void s() {}
}

class B19 : A19
{
    alias A19.s s;
    static void s(int i) {}
    override void s() {}
}

class C19
{
    void f() {
        B19.s(0);
    }
}

void test19()
{
}


/*******************************************/

class U {}
class T : U {}

void test20()
{
        T*   ptr;
        T[2] sar;
        T[]  dar;

        // all of the following should work according to the "Implicit
        // Conversions" section of the spec

        tPtr(ptr);
        tPtr(sar.ptr);
        tPtr(dar.ptr);
        tDar(sar);

//      uPtr(ptr);      // T* => U*
//      uPtr(sar);      // T[2] => U*
//      uPtr(dar);      // T[] => U*
//      uSar(sar);      // T[2] => U[2]
//      uDar(sar);      // T[2] => U[]

        uDar(dar);      // T[] => const(U)[]
        vPtr(ptr);      // T* => void*
        vPtr(sar.ptr);
        vPtr(dar.ptr);

        vDar(sar);
        vDar(dar);      // works, but T[] => void[] isn't mentioned in the spec
}

void tPtr(T*t){}
void tDar(T[]t){}
void uPtr(U*u){}
void uSar(U[2]u){}
void uDar(const(U)[]u){}
void vPtr(void*v){}
void vDar(void[]v){}


/*******************************************/

struct Foo21
{
    int i;
}

template some_struct_instance(T)
{
    static Foo21 some_struct_instance =
    {
        5,
    };
}

void test21()
{
    alias some_struct_instance!(int) inst;
    assert(inst.i == 5);
}

/*******************************************/

struct Foo22(T) {}

void test22()
{
    int i;

    if ((Foo22!(char)).init == (Foo22!(char)).init)
        i = 1;
    assert(i == 1);
}

/*******************************************/

int foo24(int i ...)
{
    return i;
}

void test24()
{
    assert(foo24(3) == 3);
}

/*******************************************/

void test25()
{
    ireal x = 4.0Li;
    ireal y = 4.0Li;
    ireal z = 4Li;
    creal c = 4L + 0Li;
}

/*******************************************/

struct Foo26
{
    int a;

    static Foo26 opCall(int i)
    {   Foo26 f;
        f.a += i;
        return f;
    }
}

void test26()
{   Foo26 f;

    f = cast(Foo26)3;
    assert(f.a == 3);

    Foo26 g = 3;
    assert(g.a == 3);
}

/*******************************************/

struct S27
{
    int x;

    void opAssign(int i)
    {
        x = i + 1;
    }
}

void test27()
{
    S27 s;
    s = 1;
    assert(s.x == 2);
}

/*******************************************/

class C28
{
    int x;

    void opAssign(int i)
    {
        x = i + 1;
    }
}

void test28()
{
// No longer supported for 2.0
//    C28 s = new C28;
//    s = 1;
//    assert(s.x == 2);
}

/*******************************************/

struct S29
{
    static S29 opCall(int v)
    {
        S29 result;
        result.v = v;
        return result;
    }
    int a;
    int v;
    int x,y,z;
}

int foo29()
{
   auto s = S29(5);
   return s.v;
}

void test29()
{
    int i = foo29();
    printf("%d\n", i);
    assert(i == 5);
}

/*******************************************/

struct S30
{
    static S30 opCall(int v)
    {
        S30 result;

        void bar()
        {
            result.v += 1;
        }

        result.v = v;
        bar();
        return result;
    }
    int a;
    int v;
    int x,y,z;
}

int foo30()
{
   auto s = S30(5);
   return s.v;
}

void test30()
{
    int i = foo30();
    printf("%d\n", i);
    assert(i == 6);
}

/*******************************************/

struct S31
{
    static void abc(S31 *r)
    {
        r.v += 1;
    }

    static S31 opCall(int v)
    {
        S31 result;

        void bar()
        {
            abc(&result);
        }

        result.v = v;
        bar();
        return result;
    }
    int a;
    int v;
    int x,y,z;
}

int foo31()
{
   auto s = S31(5);
   return s.v;
}

void test31()
{
    int i = foo31();
    printf("%d\n", i);
    assert(i == 6);
}

/*******************************************/


struct T32
{
    int opApply(int delegate(ref int i) dg)
    {
        int i;
        return dg(i);
    }
}

struct S32
{
    static void abc(S32 *r)
    {
        r.v += 1;
    }

    static S32 opCall(int v)
    {
        S32 result;
        T32 t;

        result.v = v;
        foreach (i; t)
        {
            result.v += 1;
            break;
        }
        return result;
    }
    int a;
    int v;
    int x,y,z;
}

int foo32()
{
   auto s = S32(5);
   return s.v;
}

void test32()
{
    int i = foo32();
    printf("%d\n", i);
    assert(i == 6);
}

/*******************************************/

class Confectionary
{
    this(int sugar)
    {
        //if (sugar < 500)
        //    tastiness = 200;

        //for (int i = 0; i < 10; ++i)
        //    tastiness = 300;

        //int[] tastinesses_array;

        //foreach (n; tastinesses_array)
        //    tastiness = n;

        //int[int] tastinesses_aa;

        //foreach (n; tastinesses_aa)
        //    tastiness = n;

        tastiness = 1;
    }

   const int tastiness;
}

void test33()
{
}

/*******************************************/

template a35(string name, T...)
{
    int a35(M...)(M m)
    {
        return 3;
    }
}

void test35()
{
    assert(a35!("adf")() == 3);
}

/*******************************************/

struct Q37 {
    Y37 opCast() {
        return Y37.init;
    }
}

struct Y37 {
    Q37 asdfg() {
        return Q37.init;
    }

    void hjkl() {
        Q37 zxcvb = asdfg();  // line 13
    }
}

void test37()
{
}

/*******************************************/



class C38 { }

const(Object)[] foo38(C38[3] c) @system
{   const(Object)[] x = c;
    return x;
}

void test38()
{
}

/*******************************************/

void test42()
{
    struct X { int x; }

    X x;
    assert(x.x == 0);
    x = x.init;
    assert(x.x == 0);
}

/*******************************************/

class C45
{
    void func(lazy size_t x)
    {
        (new C45).func(super.toHash());
    }
}

void test45()
{
}

/*******************************************/

template T46(double v)
{
    double T46 = v;
}

void test46()
{
    double g = T46!(double.nan) + T46!(-double.nan);
}

/*******************************************/

void test47()
{
    uint* where = (new uint[](5)).ptr;

    where[0 .. 5] = 1;
    assert(where[2] == 1);
    where[0 .. 0] = 0;
    assert(where[0] == 1);
    assert(where[2] == 1);
}

/*******************************************/

void test48()
{
    Object o = new Object();
    printf("%.*s\n", cast(int)typeof(o).classinfo.name.length, typeof(o).classinfo.name.ptr);
    printf("%.*s\n", cast(int)(typeof(o)).classinfo.name.length, (typeof(o)).classinfo.name.ptr);
    printf("%.*s\n", cast(int)(Object).classinfo.name.length, (Object).classinfo.name.ptr);
}

/*******************************************/

void test49()
{
    foo49();
}

void foo49()
{
    char[] bar;
    assert(true, bar ~ "foo");
}

/*******************************************/

void test50()
{
    foo50("foo");
}

void foo50(string bar)
{
    assert(true, bar ~ "foo");
}

/*******************************************/

struct Foo51
{
    static Foo51 opCall()
    {
      return Foo51.init;
    }
    private char[] _a;
    private bool _b;
}

void test51()
{
}

/*******************************************/

template A52(T ...) { }
mixin A52!(["abc2", "def"]);

void test52()
{
}

/*******************************************/

enum: int
{
        AF_INET53 =       2,
        PF_INET53 =       AF_INET53,
}

enum: int
{
        SOCK_STREAM53 =     1,
}

struct sockaddr_in53
{
        int sin_family = AF_INET53;
}

enum AddressFamily53: int
{
        INET =       AF_INET53,
}

enum SocketType53: int
{
        STREAM =     SOCK_STREAM53,
}


class Socket53
{
        this(AddressFamily53 af, SocketType53 type)
        {
        }
}

void test53()
{
    new Socket53(AddressFamily53.INET, SocketType53.STREAM);
}

/*******************************************/

void test54()
{
    int[2][] a;
    a ~= [1,2];
    assert(a.length == 1);
    assert(a[0][0] == 1);
    assert(a[0][1] == 2);
}

/*******************************************/

void test55()
{
        float[][] a = new float [][](1, 1);

        if((a.length != 1) || (a[0].length != 1)){
                assert(0);
        }
        if (a[0][0] == a[0][0]){
                assert(0);
        }
}

/*******************************************/

class Foo60(T)
{
    this() { unknown_identifier; }
}

void test60()
{
    bool foobar = is( Foo60!(int) );
    assert(!foobar);
}


/*******************************************/

void repeat( int n, void delegate() dg )
{
    printf("n = %d\n", n);
    if( n&1 ) dg();
    if( n/2 ) repeat( n/2, {dg();dg();} );
}

void test61()
{
    repeat( 10, {printf("Hello\n");} );
}

/*******************************************/

struct Vector65(T, uint dim)
{
  T[dim]  data;
}

T dot65(T, uint dim)(Vector65!(T,dim) a, Vector65!(T,dim) b)
{
  T tmp;
  for ( int i = 0; i < dim; ++i )
    tmp += a.data[i] * b.data[i];
  return tmp;
}

void test65()
{
  Vector65!(double,3u) a,b;
  auto t = dot65(a,b);
}


/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=18576

void delegate() callback;

struct S66 {
    int x;
    @disable this(this);

    this(int x) {
        this.x = x;
        callback = &inc;
    }
    void inc() {
        x++;
    }
}

auto f66()
{
    return g66();   // RVO should be done
}

auto g66()
{
    return h66();   // RVO should be done
}

auto h66()
{
    return S66(100);
}

void test18576()
{
    auto s = f66();
    printf("%p vs %p\n", &s, callback.ptr);
    callback();
    printf("s.x = %d\n", s.x);
    assert(s.x == 101);
    assert(&s == callback.ptr);
}

/*******************************************/

void main()
{
    printf("Start\n");

    test1();
    test2();
    test3();
    test4();
    test6();
    test7();
    test9();
    test10();
    test11();
    test12();
    test13();
    test14();
    test15();
    test17();
    test18();
    test19();
    test20();
    test21();
    test22();
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
    test37();
    test38();
    test42();
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
    test60();
    test61();
    test65();
    test18576();

    printf("Success\n");
}

