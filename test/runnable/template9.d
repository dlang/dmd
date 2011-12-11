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
// 6404

// receive only rvalue
void rvalue(T)(auto ref T x) if (!__traits(isRef, x)) {}
void rvalueVargs(T...)(auto ref T x) if (!__traits(isRef, x[0])) {}

// receive only lvalue
void lvalue(T)(auto ref T x) if ( __traits(isRef, x)) {}
void lvalueVargs(T...)(auto ref T x) if ( __traits(isRef, x[0])) {}

void test6404()
{
    int n;

    static assert(!__traits(compiles, rvalue(n)));
    static assert( __traits(compiles, rvalue(0)));

    static assert( __traits(compiles, lvalue(n)));
    static assert(!__traits(compiles, lvalue(0)));

    static assert(!__traits(compiles, rvalueVargs(n)));
    static assert( __traits(compiles, rvalueVargs(0)));

    static assert( __traits(compiles, lvalueVargs(n)));
    static assert(!__traits(compiles, lvalueVargs(0)));
}

/**********************************/
// 2246

class A2246(T,d){
    T p;
}

class B2246(int rk){
    int[rk] p;
}

class C2246(T,int rk){
    T[rk] p;
}

template f2246(T:A2246!(U,d),U,d){
    void f2246(){ }
}

template f2246(T:B2246!(rank),int rank){
    void f2246(){ }
}

template f2246(T:C2246!(U,rank),U,int rank){
    void f2246(){ }
}

void test2246(){
    A2246!(int,long) a;
    B2246!(2) b;
    C2246!(int,2) c;
    f2246!(A2246!(int,long))();
    f2246!(B2246!(2))();
    f2246!(C2246!(int,2))();
}

/**********************************/
// 1684

template Test1684( uint memberOffset ){}

class MyClass1684 {
    int flags2;
    mixin Test1684!(cast(uint)flags2.offsetof) t1; // compiles ok
    mixin Test1684!(cast(int)flags2.offsetof)  t2; // compiles ok
    mixin Test1684!(flags2.offsetof)           t3; // Error: no property 'offsetof' for type 'int'
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

/***************************************/
// 2579

void foo2579(T)(T delegate(in Object) dlg)
{
}

void test2579()
{
    foo2579( (in Object) { return 15; } );
}

/**********************************/
// 5886 & 5393

struct K5886 {
    void get1(this T)() const {
        pragma(msg, T);
    }
    void get2(int N=4, this T)() const {
        pragma(msg, N, " ; ", T);
    }
}

void test5886() {
    K5886 km;
    const(K5886) kc;
    immutable(K5886) ki;

    km.get1;        // OK
    kc.get1;        // OK
    ki.get1;        // OK
    km.get2;        // OK
    kc.get2;        // OK
    ki.get2;        // OK
    km.get2!(1, K5886);             // Ugly
    kc.get2!(2, const(K5886));      // Ugly
    ki.get2!(3, immutable(K5886));  // Ugly
    km.get2!8;      // Error
    kc.get2!9;      // Error
    ki.get2!10;     // Error
}

// --------

void test5393()
{
    class A
    {
        void opDispatch (string name, this T) () { }
    }

    class B : A {}

    auto b = new B;
    b.foobar();
}

/**********************************/
// 6825

void test6825()
{
    struct File
    {
        void write(S...)(S args) {}
    }

    void dump(void delegate(string) d) {}

    auto o = File();
    dump(&o.write!string);
}

/**********************************/
// 6789

template isStaticArray6789(T)
{
    static if (is(T U : U[N], size_t N))    // doesn't match
    {
        pragma(msg, "> U = ", U, ", N:", typeof(N), " = ", N);
        enum isStaticArray6789 = true;
    }
    else
        enum isStaticArray6789 = false;
}

void test6789()
{
    alias int[3] T;
    static assert(isStaticArray6789!T);
}

/**********************************/
// 2778

struct ArrayWrapper2778(T)
{
    T[] data;
    alias data this;
}

void doStuffFunc2778(int[] data) {}

void doStuffTempl2778(T)(T[] data) {}

int doStuffTemplOver2778(T)(void* data) { return 1; }
int doStuffTemplOver2778(T)(ArrayWrapper2778!T w) { return 2; }

void test2778()
{
    ArrayWrapper2778!(int) foo;

    doStuffFunc2778(foo);  // Works.

    doStuffTempl2778!(int)(foo);  // Works.

    doStuffTempl2778(foo);  // Error

    assert(doStuffTemplOver2778(foo) == 2);
}

// ----

void test2778aa()
{
    void foo(K, V)(V[K] aa){ pragma(msg, "K=", K, ", V=", V); }

    int[string] aa1;
    foo(aa1);   // OK

    struct SubTypeOf(T)
    {
        T val;
        alias val this;
    }
    SubTypeOf!(string[char]) aa2;
    foo(aa2);   // NG
}

// ----

void test2778get()
{
    void foo(ubyte[]){}

    static struct S
    {
        ubyte[] val = [1,2,3];
        @property ref ubyte[] get(){ return val; }
        alias get this;
    }
    S s;
    foo(s);
}

/**********************************/
// 6805

struct T6805
{
    template opDispatch(string name)
    {
        alias int Type;
    }
}
static assert(is(T6805.xxx.Type == int));

/**********************************/
// 6994

struct Foo6994
{
    T get(T)(){ return T.init; }

    T func1(T)()
    if (__traits(compiles, get!T()))
    { return get!T; }

    T func2(T)()
    if (__traits(compiles, this.get!T()))   // add explicit 'this'
    { return get!T; }
}
void test6994()
{
    Foo6994 foo;
    foo.get!int();      // OK
    foo.func1!int();    // OK
    foo.func2!int();    // NG
}

/**********************************/
// 3467 & 6806

struct Foo3467( uint n )
{
    Foo3467!( n ) bar( ) {
        typeof( return ) result;
        return result;
    }
}
struct Vec3467(size_t N)
{
    void opBinary(string op:"~", size_t M)(Vec3467!M) {}
}
void test3467()
{
    Foo3467!( 4 ) baz;
    baz = baz.bar;// FAIL

    Vec3467!2 a1;
    Vec3467!3 a2;
    a1 ~ a2; // line 7, Error
}

struct TS6806(size_t n) { pragma(msg, typeof(n)); }
static assert(is(TS6806!(1u) == TS6806!(1)));

/**********************************/
// 2550

template pow10_2550(long n)
{
    const long pow10_2550 = 0;
    static if (n < 0)
        const long pow10_2550 = 0;
    else
        const long pow10_2550 = 10 * pow10_2550!(n - 1);
}
template pow10_2550(long n:0)
{
    const long pow10_2550 = 1;
}
static assert(pow10_2550!(0) == 1);

/**********************************/

void foo10(T)(T prm)
{
    pragma(msg, T);
    static assert(is(T == const(int)[]));
}
void bar10(T)(T prm)
{
    pragma(msg, T);
    static assert(is(T == const(int)*));
}
void test10()
{
    const a = [1,2,3];
    static assert(is(typeof(a) == const(int[])));
    foo10(a);

    int n;
    const p = &n;
    static assert(is(typeof(p) == const(int*)));
    bar10(p);
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
    test6404();
    test2246();
    bug4984();
    test2579();
    test5886();
    test5393();
    test6825();
    test6789();
    test2778();
    test2778aa();
    test2778get();
    test6994();
    test3467();
    test10();

    printf("Success\n");
    return 0;
}
