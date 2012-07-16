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
// 1780

template Tuple1780(Ts ...) { alias Ts Tuple1780; }

template Decode1780( T )                            { alias Tuple1780!() Types; }
template Decode1780( T : TT!(Us), alias TT, Us... ) { alias Us Types; }

void test1780()
{
    struct S1780(T1, T2) {}

    // should extract tuple (bool,short) but matches the first specialisation
    alias Decode1780!( S1780!(bool,short) ).Types SQ1780;  // --> SQ2 is empty tuple!
    static assert(is(SQ1780 == Tuple1780!(bool, short)));
}

/**********************************/
// 3608

template foo3608(T, U){}

template BaseTemplate3608(alias TTT : U!V, alias U, V...)
{
    alias U BaseTemplate3608;
}
template TemplateParams3608(alias T : U!V, alias U, V...)
{
    alias V TemplateParams3608;
}

template TyueTuple3608(T...) { alias T TyueTuple3608; }

void test3608()
{
    alias foo3608!(int, long) Foo3608;

    static assert(__traits(isSame, BaseTemplate3608!Foo3608, foo3608));
    static assert(is(TemplateParams3608!Foo3608 == TyueTuple3608!(int, long)));
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
  // Note: compiling this overflows the stack if dmd is build with DEBUG
  //bug4984a!400();
    bug4984a!200();
    bug4984b(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19);
}

/***************************************/
// 2579

void foo2579(T)(T delegate(in Object) dlg)
{
}

void test2579()
{
    foo2579( (in Object o) { return 15; } );
}

/**********************************/
// 4953

void bug4953(T = void)(short x) {}
static assert(is(typeof(bug4953(3))));

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
// 5896

struct X5896
{
                 T opCast(T)(){ return 1; }
           const T opCast(T)(){ return 2; }
       immutable T opCast(T)(){ return 3; }
          shared T opCast(T)(){ return 4; }
    const shared T opCast(T)(){ return 5; }
}
void test5896()
{
    auto xm =              X5896  ();
    auto xc =        const(X5896) ();
    auto xi =    immutable(X5896) ();
    auto xs =       shared(X5896) ();
    auto xcs= const(shared(X5896))();
    assert(cast(int)xm == 1);
    assert(cast(int)xc == 2);
    assert(cast(int)xi == 3);
    assert(cast(int)xs == 4);
    assert(cast(int)xcs== 5);
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
// 6208

int getRefNonref(T)(ref T s){ return 1; }
int getRefNonref(T)(    T s){ return 2; }

int getAutoRef(T)(auto ref T s){ return __traits(isRef, s) ? 1 : 2; }

void getOut(T)(out T s){ ; }

void getLazy1(T=int)(lazy void s){ s(), s(); }
void getLazy2(T)(lazy T s){  s(), s(); }

void test6208a()
{
    int lvalue;
    int rvalue(){ int t; return t; }

    assert(getRefNonref(lvalue  ) == 1);
    assert(getRefNonref(rvalue()) == 2);

    assert(getAutoRef(lvalue  ) == 1);
    assert(getAutoRef(rvalue()) == 2);

    static assert( __traits(compiles, getOut(lvalue  )));
    static assert(!__traits(compiles, getOut(rvalue())));

    int n1; getLazy1(++n1); assert(n1 == 2);
    int n2; getLazy2(++n2); assert(n2 == 2);

    struct X
    {
        int f(T)(auto ref T t){ return 1; }
        int f(T)(auto ref T t, ...){ return -1; }
    }
    auto xm =       X ();
    auto xc = const(X)();
    int n;
    assert(xm.f!int(n) == 1);   // resolved 'auto ref'
    assert(xm.f!int(0) == 1);   // ditto
}

void test6208b()
{
    void foo(T)(const T value) if (!is(T == int)) {}

    int mn;
    const int cn;
    static assert(!__traits(compiles, foo(mn)));    // OK -> OK
    static assert(!__traits(compiles, foo(cn)));    // NG -> OK
}

void test6208c()
{
    struct S
    {
        // Original test case.
        int foo(V)(in V v)                         { return 1; }
        int foo(Args...)(auto ref const Args args) { return 2; }

        // Reduced test cases

        int hoo(V)(const V v)             { return 1; }  // typeof(10) : const V       -> MATCHconst
        int hoo(Args...)(const Args args) { return 2; }  // typeof(10) : const Args[0] -> MATCHconst
        // If deduction matching level is same, tuple parameter is less specialized than others.

        int bar(V)(V v)                   { return 1; }  // typeof(10) : V             -> MATCHexact
        int bar(Args...)(const Args args) { return 2; }  // typeof(10) : const Args[0] -> MATCHconst

        int baz(V)(const V v)             { return 1; }  // typeof(10) : const V -> MATCHconst
        int baz(Args...)(Args args)       { return 2; }  // typeof(10) : Args[0] -> MATCHexact

        inout(int) war(V)(inout V v)            { return 1; }
        inout(int) war(Args...)(inout Args args){ return 2; }

        inout(int) waz(Args...)(inout Args args){ return 0; }   // wild deduction test
    }

    S s;

    int nm = 10;
    assert(s.foo(nm) == 1);
    assert(s.hoo(nm) == 1);
    assert(s.bar(nm) == 1);
    assert(s.baz(nm) == 2);
    assert(s.war(nm) == 1);
    static assert(is(typeof(s.waz(nm)) == int));

    const int nc = 10;
    assert(s.foo(nc) == 1);
    assert(s.hoo(nc) == 1);
    assert(s.bar(nc) == 1);
    assert(s.baz(nc) == 1);
    assert(s.war(nc) == 1);
    static assert(is(typeof(s.waz(nc)) == const(int)));

    immutable int ni = 10;
    assert(s.foo(ni) == 1);
    assert(s.hoo(ni) == 1);
    assert(s.bar(ni) == 1);
    assert(s.baz(ni) == 2);
    assert(s.war(ni) == 1);
    static assert(is(typeof(s.waz(ni)) == immutable(int)));

    static assert(is(typeof(s.waz(nm, nm)) == int));
    static assert(is(typeof(s.waz(nm, nc)) == const(int)));
    static assert(is(typeof(s.waz(nm, ni)) == const(int)));
    static assert(is(typeof(s.waz(nc, nm)) == const(int)));
    static assert(is(typeof(s.waz(nc, nc)) == const(int)));
    static assert(is(typeof(s.waz(nc, ni)) == const(int)));
    static assert(is(typeof(s.waz(ni, nm)) == const(int)));
    static assert(is(typeof(s.waz(ni, nc)) == const(int)));
    static assert(is(typeof(s.waz(ni, ni)) == immutable(int)));
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
// 6738

struct Foo6738
{
    int _val = 10;

    @property int val()() { return _val; }
    int get() { return val; }  // fail
}

void test6738()
{
    Foo6738 foo;
    auto x = foo.val;  // ok
    assert(x == 10);
    assert(foo.get() == 10);
}

/**********************************/
// 7498

template IndexMixin(){
    void insert(T)(T value){  }
}

class MultiIndexContainer{
    mixin IndexMixin!() index0;
    class Index0{
        void baburk(){
            this.outer.index0.insert(1);
        }
    }
}

/**********************************/
// 6780

@property int foo6780()(){ return 10; }

int g6780;
@property void bar6780()(int n){ g6780 = n; }

void test6780()
{
    auto n = foo6780;
    assert(n == 10);

    bar6780 = 10;
    assert(g6780 == 10);
}

/**********************************/
// 6891

struct S6891(int N, T)
{
    void f(U)(S6891!(N, U) u) { }
}

void test6891()
{
    alias S6891!(1, void) A;
    A().f(A());
}

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
// 4413

struct Foo4413
{
    alias typeof(this) typeof_this;
    void bar1(typeof_this other) {}
    void bar2()(typeof_this other) {}
    void bar3(typeof(this) other) {}
    void bar4()(typeof(this) other) {}
}

void test4413()
{
    Foo4413 f;
    f.bar1(f); // OK
    f.bar2(f); // OK
    f.bar3(f); // OK
    f.bar4(f); // ERR
}

/**********************************/
// 4675

template isNumeric(T)
{
    enum bool test1 = is(T : long);     // should be hidden
    enum bool test2 = is(T : real);     // should be hidden
    enum bool isNumeric = test1 || test2;
}
void test4675()
{
    static assert( isNumeric!int);
    static assert(!isNumeric!string);
    static assert(!__traits(compiles, isNumeric!int.test1));   // should be an error
    static assert(!__traits(compiles, isNumeric!int.test2));   // should be an error
    static assert(!__traits(compiles, isNumeric!int.isNumeric));
}

/**********************************/
// 5525

template foo5525(T)
{
    T foo5525(T t)      { return t; }
    T foo5525(T t, T u) { return t + u; }
}

void test5525()
{
    alias foo5525!int f;
    assert(f(1) == 1);
    assert(f(1, 2) == 3);
}

/**********************************/
// 5801

int a5801;
void bar5801(T = double)(typeof(a5801) i) {}
void baz5801(T)(typeof(a5801) i, T t) {}
void test5801()
{
    bar5801(2);  // Does not compile.
    baz5801(3, "baz"); // Does not compile.
}

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
void boo10(T)(ref T val)        // ref paramter doesn't remove top const
{
    pragma(msg, T);
    static assert(is(T == const(int[])));
}
void goo10(T)(auto ref T val)   // auto ref with lvalue doesn't
{
    pragma(msg, T);
    static assert(is(T == const(int[])));
}
void hoo10(T)(auto ref T val)   // auto ref with rvalue does
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
    boo10(a);
    goo10(a);
    hoo10(cast(const(int[]))[1,2,3]);

    int n;
    const p = &n;
    static assert(is(typeof(p) == const(int*)));
    bar10(p);
}

/**********************************/
// 3092

template Foo3092(A...)
{
    alias A[0] Foo3092;
}
static assert(is(Foo3092!(int, "foo") == int));

/**********************************/
// 7037

struct Foo7037 {}
struct Bar7037 { Foo7037 f; alias f this; }
void works7037( T )( T value ) if ( is( T : Foo7037 ) ) {}
void doesnotwork7037( T : Foo7037 )( T value ) {}

void test7037()
{
   Bar7037 b;
   works7037( b );
   doesnotwork7037( b );
}

/**********************************/
// 7110

struct S7110
{
    int opSlice(int, int) const { return 0; }
    int opSlice()         const { return 0; }
    int opIndex(int, int) const { return 0; }
    int opIndex(int)      const { return 0; }
}

enum e7110 = S7110();

template T7110(alias a) { } // or T7110(a...)

alias T7110!( S7110 ) T71100; // passes
alias T7110!((S7110)) T71101; // passes

alias T7110!( S7110()[0..0]  )  A0; // passes
alias T7110!(  (e7110[0..0]) )  A1; // passes
alias T7110!(   e7110[0..0]  )  A2; // passes

alias T7110!( S7110()[0, 0]  ) B0; // passes
alias T7110!(  (e7110[0, 0]) ) B1; // passes
alias T7110!(   e7110[0, 0]  ) B2; // passes

alias T7110!( S7110()[]  ) C0; // passes
alias T7110!(  (e7110[]) ) C1; // passes
alias T7110!(   e7110[]  ) C2; // fails: e7110 is used as a type

alias T7110!( S7110()[0]  ) D0; // passes
alias T7110!(  (e7110[0]) ) D1; // passes
alias T7110!(   e7110[0]  ) D2; // fails: e7110 must be an array or pointer type, not S7110

/**********************************/
// 7124

template StaticArrayOf(T : E[dim], E, size_t dim)
{
    pragma(msg, "T = ", T, ", E = ", E, ", dim = ", dim);
    alias E[dim] StaticArrayOf;
}

template DynamicArrayOf(T : E[], E)
{
    pragma(msg, "T = ", T, ", E = ", E);
    alias E[] DynamicArrayOf;
}

template AssocArrayOf(T : V[K], K, V)
{
    pragma(msg, "T = ", T, ", K = ", K, ", V = ", V);
    alias V[K] AssocArrayOf;
}
void test7124()
{
    struct SA { int[5] sa; alias sa this; }
    static assert(is(StaticArrayOf!SA == int[5]));

    struct DA { int[] da; alias da this; }
    static assert(is(DynamicArrayOf!DA == int[]));

    struct AA { int[string] aa; alias aa this; }
    static assert(is(AssocArrayOf!AA == int[string]));
}

/**********************************/
// 7359

bool foo7359(T)(T[] a ...)
{
    return true;
}

void test7359()
{
    assert(foo7359(1,1,1,1,1,1));               // OK
    assert(foo7359("abc","abc","abc","abc"));   // NG
}

/**********************************/
// 7363

template t7363()
{
   enum e = 0;
   static if (true)
       enum t7363 = 0;
}
static assert(!__traits(compiles, t7363!().t7363 == 0)); // Assertion fails
static assert(t7363!() == 0); // Error: void has no value

template u7363()
{
   static if (true)
   {
       enum e = 0;
       enum u73631 = 0;
   }
   alias u73631 u7363;
}
static assert(!__traits(compiles, u7363!().u7363 == 0)); // Assertion fails
static assert(u7363!() == 0); // Error: void has no value

/**********************************/

struct S4371(T ...) { }

alias S4371!("hi!") t;

static if (is(t U == S4371!(U))) { }

/**********************************/
// 7416

void t7416(alias a)() if(is(typeof(a())))
{}

void test7416() {
    void f() {}
    alias t7416!f x;
}

/**********************************/
// 7563

class Test7563
{
    void test(T, bool a = true)(T t)
    {

    }
}

void test7563()
{
    auto test = new Test7563;
    pragma(msg, typeof(test.test!(int, true)).stringof);
    pragma(msg, typeof(test.test!(int)).stringof); // Error: expression (test.test!(int)) has no type
}

/**********************************/
// 7580

struct S7580(T)
{
    void opAssign()(T value) {}
}
struct X7580(T)
{
    private T val;
    @property ref inout(T) get()() inout { return val; }    // template
    alias get this;
}
struct Y7580(T)
{
    private T val;
    @property ref auto get()() inout { return val; }        // template + auto return
    alias get this;
}

void test7580()
{
    S7580!(int) s;
    X7580!int x;
    Y7580!int y;
    s = x;
    s = y;

    shared(X7580!int) sx;
    static assert(!__traits(compiles, s = sx));
}

/**********************************/
// 7585

extern(C) alias void function() Callback;

template W7585a(alias dg)
{
    //pragma(msg, typeof(dg));
    extern(C) void W7585a() { dg(); }
}

void test7585()
{
    static void f7585a(){}
    Callback cb1 = &W7585a!(f7585a);      // OK
    static assert(!__traits(compiles,
    {
        void f7585b(){}
        Callback cb2 = &W7585a!(f7585b);  // NG
    }));

    Callback cb3 = &W7585a!((){});              // NG -> OK
    Callback cb4 = &W7585a!(function(){});      // OK
    static assert(!__traits(compiles,
    {
        Callback cb5 = &W7585a!(delegate(){});  // NG
    }));

    static int global;  // global data
    Callback cb6 = &W7585a!((){return global;});    // NG -> OK
    static assert(!__traits(compiles,
    {
        int n;
        Callback cb7 = &W7585a!((){return n;});     // NG
    }));
}

/**********************************/
// 7643

template T7643(A...){ alias A T7643; }

alias T7643!(long, "x", string, "y") Specs7643;

alias T7643!( Specs7643[] ) U7643;	// Error: tuple A is used as a type

/**********************************/
// 7671

       inout(int)[3]  id7671n1             ( inout(int)[3] );
       inout( U )[n]  id7671x1(U, size_t n)( inout( U )[n] );

shared(inout int)[3]  id7671n2             ( shared(inout int)[3] );
shared(inout  U )[n]  id7671x2(U, size_t n)( shared(inout  U )[n] );

void test7671()
{
    static assert(is( typeof( id7671n1( (immutable(int)[3]).init ) ) == immutable(int[3]) ));
    static assert(is( typeof( id7671x1( (immutable(int)[3]).init ) ) == immutable(int[3]) ));

    static assert(is( typeof( id7671n2( (immutable(int)[3]).init ) ) == immutable(int[3]) ));
    static assert(is( typeof( id7671x2( (immutable(int)[3]).init ) ) == immutable(int[3]) ));
}

/************************************/
// 7672

T foo7672(T)(T a){ return a; }

void test7672(inout(int[]) a = null, inout(int*) p = null)
{
    static assert(is( typeof(        a ) == inout(int[]) ));
    static assert(is( typeof(foo7672(a)) == inout(int)[] ));

    static assert(is( typeof(        p ) == inout(int*) ));
    static assert(is( typeof(foo7672(p)) == inout(int)* ));
}

/**********************************/
// 7684

       U[]  id7684(U)(        U[]  );
shared(U[]) id7684(U)( shared(U[]) );

void test7684()
{
    shared(int)[] x;
    static assert(is( typeof(id7684(x)) == shared(int)[] ));
}

/**********************************/
// 7694

void match7694(alias m)()
{
    m.foo();    //removing this line supresses ice in both cases
}

struct T7694
{
    void foo(){}
    void bootstrap()
    {
    //next line causes ice
        match7694!(this)();
    //while this works:
        alias this p;
        match7694!(p)();
    }
}

/**********************************/
// 7755

template to7755(T)
{
    T to7755(A...)(A args)
    {
        return toImpl7755!T(args);
    }
}

T toImpl7755(T, S)(S value)
{
    return T.init;
}

template Foo7755(T){}

struct Bar7755
{
    void qux()
    {
        if (is(typeof(to7755!string(Foo7755!int)))){};
    }
}

/**********************************/

       inout(U)[]  id11a(U)(        inout(U)[]  );
       inout(U[])  id11a(U)(        inout(U[])  );
inout(shared(U[])) id11a(U)( inout(shared(U[])) );

void test11a(inout int _ = 0)
{
    shared(const(int))[] x;
    static assert(is( typeof(id11a(x)) == shared(const(int))[] ));

    shared(int)[] y;
    static assert(is( typeof(id11a(y)) == shared(int)[] ));

    inout(U)[n] idz(U, size_t n)( inout(U)[n] );

    inout(shared(bool[1])) z;
    static assert(is( typeof(idz(z)) == inout(shared(bool[1])) ));
}

inout(U[]) id11b(U)( inout(U[]) );

void test11b()
{
    alias const(shared(int)[]) T;
    static assert(is(typeof(id11b(T.init)) == const(shared(int)[])));
}

/**********************************/
// 7769

void f7769(K)(inout(K) value){}
void test7769()
{
    f7769("abc");
}

/**********************************/
// 7812

template A7812(T...) {}

template B7812(alias C) if (C) {}

template D7812()
{
    alias B7812!(A7812!(NonExistent!())) D7812;
}

static assert(!__traits(compiles, D7812!()));

/**********************************/
// 7873

inout(T)* foo(T)(inout(T)* t)
{
    static assert(is(T == int*));
    return t;
}

inout(T)* bar(T)(inout(T)* t)
{
    return foo(t);
}

void test7873()
{
    int *i;
    bar(&i);
}

/**********************************/
// 7933

struct Boo7933(size_t dim){int a;}
struct Baa7933(size_t dim)
{
    Boo7933!dim a;
    //Boo7933!1 a; //(1) This version causes no errors
}

auto foo7933()(Boo7933!1 b){return b;}
//auto fuu7933(Boo7933!1 b){return b;} //(2) This line neutralizes the error

void test7933()
{
    Baa7933!1 a; //(3) This line causes the error message
    auto b = foo7933(Boo7933!1(1));
}

/**********************************/
// 8094

struct Tuple8094(T...) {}

template getParameters8094(T, alias P)
{
    static if (is(T t == P!U, U...))
        alias U getParameters8094;
    else
        static assert(false);
}

void test8094()
{
    alias getParameters8094!(Tuple8094!(int, string), Tuple8094) args;
}

/**********************************/

struct Tuple12(T...)
{
    void foo(alias P)()
    {
        alias Tuple12 X;
        static if (is(typeof(this) t == X!U, U...))
            alias U getParameters;
        else
            static assert(false);
    }
}

void test12()
{
    Tuple12!(int, string) t;
    t.foo!Tuple12();
}

/**********************************/
// 8125

void foo8125(){}

struct X8125(alias a) {}

template Y8125a(T : A!f, alias A, alias f) {}  //OK
template Y8125b(T : A!foo8125, alias A) {}     //NG

void test8125()
{
    alias Y8125a!(X8125!foo8125) y1;
    alias Y8125b!(X8125!foo8125) y2;
}

/**********************************/

struct A13() {}
struct B13(TT...) {}
struct C13(T1) {}
struct D13(T1, TT...) {}
struct E13(T1, T2) {}
struct F13(T1, T2, TT...) {}

template Test13(alias X)
{
    static if (is(X x : P!U, alias P, U...))
        enum Test13 = true;
    else
        enum Test13 = false;
}

void test13()
{
    static assert(Test13!( A13!() ));
    static assert(Test13!( B13!(int) ));
    static assert(Test13!( B13!(int, double) ));
    static assert(Test13!( B13!(int, double, string) ));
    static assert(Test13!( C13!(int) ));
    static assert(Test13!( D13!(int) ));
    static assert(Test13!( D13!(int, double) ));
    static assert(Test13!( D13!(int, double, string) ));
    static assert(Test13!( E13!(int, double) ));
    static assert(Test13!( F13!(int, double) ));
    static assert(Test13!( F13!(int, double, string) ));
    static assert(Test13!( F13!(int, double, string, bool) ));
}

/**********************************/

struct A14(T, U, int n = 1)
{
}

template Test14(alias X)
{
    static if (is(X x : P!U, alias P, U...))
        alias U Test14;
    else
        static assert(0);
}

void test14()
{
    alias A14!(int, double) Type;
    alias Test14!Type Params;
    static assert(Params.length == 3);
    static assert(is(Params[0] == int));
    static assert(is(Params[1] == double));
    static assert(   Params[2] == 1);
}

/**********************************/
// 8129

class X8129 {}
class A8129 {}
class B8129 : A8129 {}

int foo8129(T : A8129)(X8129 x) { return 1; }
int foo8129(T : A8129)(X8129 x, void function (T) block) { return 2; }

int bar8129(T, R)(R range, T value) { return 1; }

int baz8129(T, R)(R range, T value) { return 1; }
int baz8129(T, R)(R range, Undefined value) { return 2; }

void test8129()
{
    auto x = new X8129;
    assert(x.foo8129!B8129()      == 1);
    assert(x.foo8129!B8129((a){}) == 2);
    assert(foo8129!B8129(x)        == 1);
    assert(foo8129!B8129(x, (a){}) == 2);
    assert(foo8129!B8129(x)              == 1);
    assert(foo8129!B8129(x, (B8129 b){}) == 2);

    ubyte[] buffer = [0, 1, 2];
    assert(bar8129!ushort(buffer, 915) == 1);

    // While deduction, parameter type 'Undefined' shows semantic error.
    static assert(!__traits(compiles, {
        baz8129!ushort(buffer, 915);
    }));
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
    test1780();
    test3608();
    test6404();
    test2246();
    bug4984();
    test2579();
    test5886();
    test5393();
    test5896();
    test6825();
    test6789();
    test2778();
    test2778aa();
    test2778get();
    test6208a();
    test6208b();
    test6208c();
    test6738();
    test6780();
    test6891();
    test6994();
    test3467();
    test4413();
    test5525();
    test5801();
    test10();
    test7037();
    test7124();
    test7359();
    test7416();
    test7563();
    test7580();
    test7585();
    test7671();
    test7672();
    test7684();
    test11a();
    test11b();
    test7769();
    test7873();
    test7933();
    test8094();
    test12();
    test8125();
    test13();
    test14();
    test8129();

    printf("Success\n");
    return 0;
}
