// PERMUTE_ARGS:

/**************************************************
    1748 class template with stringof
**************************************************/

struct S1748(T) {}
static assert(S1748!int.stringof == "S1748!int");

class C1748(T) {}
static assert(C1748!int.stringof == "C1748!int");

/**************************************************
    5996    ICE(expression.c)
**************************************************/

template T5996(T)
{
    auto bug5996() {
        if (anyOldGarbage) {}
        return 2;
    }
}
static assert(!is(typeof(T5996!(int).bug5996())));

/**************************************************
    8532    segfault(mtype.c) - type inference + pure
**************************************************/
auto segfault8532(Y, R ...)(R r, Y val) pure
{ return segfault8532(r, val); }

static assert(!is(typeof( segfault8532(1,2,3))));

/**************************************************
    8982    ICE(ctfeexpr.c) __parameters with error in default value
**************************************************/
template ice8982(T)
{
    void bug8982(ref const int v = 7){}

    static if (is(typeof(bug8982) P == __parameters)) {
        pragma(msg, ((P[0..1] g) => g[0])());
    }
}

static assert(!is(ice8982!(int)));


/**************************************************
    8801    ICE assigning to __ctfe
**************************************************/
static assert(!is(typeof( { bool __ctfe= true; })));
static assert(!is(typeof( { __ctfe |= true; })));

/**************************************************
    5932    ICE(s2ir.c)
    6675    ICE(glue.c)
**************************************************/

void bug3932(T)() {
    static assert( 0 );
    func5932( 7 );
}

void func5932(T)( T val ) {
    void onStandardMsg() {
        foreach( t; T ) { }
    }
}

static assert(!is(typeof(
    {
        bug3932!(int)();
    }()
)));

/**************************************************
    6650    ICE(glue.c) or wrong-code
**************************************************/

auto bug6650(X)(X y)
{
    X q;
    q = "abc";
    return y;
}

static assert(!is(typeof(bug6650!(int)(6))));
static assert(!is(typeof(bug6650!(int)(18))));

/**************************************************
  6661 Templates instantiated only through is(typeof()) shouldn't cause errors
**************************************************/

template bug6661(Q)
{
    int qutz(Q y)
    {
        Q q = "abc";
        return 67;
    }
    static assert(qutz(13).sizeof!=299);
    const Q blaz = 6;
}

static assert(!is(typeof(bug6661!(int).blaz)));

template bug6661x(Q)
{
    int qutz(Q y)
    {
        Q q = "abc";
        return 67;
    }
}
// should pass, but doesn't in current
//static assert(!is(typeof(bug6661x!(int))));

/**************************************************
    6599    ICE(constfold.c) or segfault
**************************************************/

string bug6599extraTest(string x) { return x ~ "abc"; }

template Bug6599(X)
{
    class Orbit
    {
        Repository repository = Repository();
    }

    struct Repository
    {
        string fileProtocol = "file://";
        string blah = bug6599extraTest("abc");
        string source = fileProtocol ~ "/usr/local/orbit/repository";
    }
}

static assert(!is(typeof(Bug6599!int)));

/**************************************************
    8422    TypeTuple of tuples can't be read at compile time
**************************************************/

template TypeTuple8422(TList...)
{
    alias TList TypeTuple8422;
}

struct S8422 { int x; }

void test8422()
{
    enum a = S8422(1);
    enum b = S8422(2);
    enum c = [1,2,3];
    foreach(t; TypeTuple8422!(b, a)) {
        enum u = t;
    }
    foreach(t; TypeTuple8422!(c)) {
        enum v = t;
    }
}

/**************************************************
    6096    ICE(el.c) with -O
**************************************************/

cdouble c6096;

int bug6096()
{
    if (c6096) return 0;
    return 1;
}

/**************************************************
    7681  Segfault
**************************************************/

static assert( !is(typeof( (){
      undefined ~= delegate(){}; return 7;
  }())));

/**************************************************
    8639  Buffer overflow
**************************************************/

void t8639(alias a)() {}
void bug8639() {
  t8639!({auto r = -real.max;})();
}

/**************************************************
    7751  Segfault
**************************************************/

static assert( !is(typeof( (){
    bar[]r; r ~= [];
     return 7;
  }())));

/**************************************************
    7639  Segfault
**************************************************/

static assert( !is(typeof( (){
    enum foo =
    [
        str : "functions",
    ];
})));

/**************************************************
    5796
**************************************************/

template A(B) {
    pragma(msg, "missing ;")
    enum X = 0;
}

static assert(!is(typeof(A!(int))));

/**************************************************
    6720
**************************************************/
void bug6720() { }

static assert(!is(typeof(
cast(bool)bug6720()
)));

/**************************************************
    1099
**************************************************/

template Mix1099(int a) {
   alias typeof(this) ThisType;
    static assert (ThisType.init.tupleof.length == 2);
}


struct Foo1099 {
    mixin Mix1099!(0);
    int foo;
    mixin Mix1099!(1);
    int bar;
    mixin Mix1099!(2);
}

/**************************************************
    8788 - super() and return
**************************************************/

class B8788 {
        this ( ) { }
}

class C8788(int test) : B8788
{
    this ( int y )
    {   // TESTS WHICH SHOULD PASS
        static if (test == 1) {
            if (y == 3) {
                super();
                return;
            }
            super();
            return;
        } else static if (test == 2) {
            if (y == 3) {
                super();
                return;
            }
            super();
        } else static if (test == 3) {
            if (y > 3) {
                if (y == 7) {
                   super();
                   return;
                }
                super();
                return;
            }
            super();
        } else static if (test == 4) {
            if (y > 3) {
                if (y == 7) {
                   super();
                   return;
                }
                else if (y> 5)
                    super();
                else super();
                return;
            }
            super();
        }
        // TESTS WHICH SHOULD FAIL
        else static if (test == 5) {
            if (y == 3) {
                super();
                return;
            }
            return; // no super
        } else static if (test == 6) {
            if (y > 3) {
                if (y == 7) {
                   super();
                   return;
                }
                super();
            }
            super(); // two calls
        } else static if (test == 7) {
            if (y == 3) {
                return; // no super
            }
            super();
        } else static if (test == 8) {
            if (y > 3) {
                if (y == 7) {
                   return; // no super
                }
                super();
                return;
            }
            super();
        } else static if (test == 9) {
            if (y > 3) {
                if (y == 7) {
                   super();
                   return;
                }
                else if (y> 5)
                    super();
                else return; // no super
                return;
            }
            super();
        }
    }
}

static assert( is(typeof( { new C8788!(1)(0); } )));
static assert( is(typeof( { new C8788!(2)(0); } )));
static assert( is(typeof( { new C8788!(3)(0); } )));
static assert( is(typeof( { new C8788!(4)(0); } )));
static assert(!is(typeof( { new C8788!(5)(0); } )));
static assert(!is(typeof( { new C8788!(6)(0); } )));
static assert(!is(typeof( { new C8788!(7)(0); } )));
static assert(!is(typeof( { new C8788!(8)(0); } )));
static assert(!is(typeof( { new C8788!(9)(0); } )));

/**************************************************
    4967, 7058
**************************************************/

enum Bug7058 bug7058 = { 1.5f, 2};
static assert(bug7058.z == 99);

struct Bug7058
{
     float x = 0;
     float y = 0;
     float z = 99;
}


/***************************************************/

template test8163(T...)
{
    struct Point
    {
        T fields;
    }

    enum N = 2; // N>=2 triggers the bug
    extern Point[N] bar();

    void foo()
    {
        Point[N] _ = bar();
    }
}

alias test8163!(long) _l;
alias test8163!(double) _d;
alias test8163!(float, float) _ff;
alias test8163!(int, int) _ii;
alias test8163!(int, float) _if;
alias test8163!(ushort, ushort, ushort, ushort) _SSSS;
alias test8163!(ubyte, ubyte, ubyte, ubyte, ubyte, ubyte, ubyte, ubyte) _BBBBBBBB;
alias test8163!(ubyte, ubyte, ushort, float) _BBSf;


/***************************************************/
// 9348

void test9348()
{
    @property Object F(int E)() { return null; }

    assert(F!0 !is null);
    assert(F!0 !in [new Object():1]);
}

/***************************************************/
// 9690

@disable
{
    void dep9690() {}
    void test9690()
    {
        dep9690();      // OK
        void inner()
        {
            dep9690();  // OK <- NG
        }
    }
}

/***************************************************/
// 9987

static if (is(object.ModuleInfo == struct))
{
    struct ModuleInfo {}

    static assert(!is(object.ModuleInfo == ModuleInfo));
    static assert(object.ModuleInfo.sizeof != ModuleInfo.sizeof);
}
static if (is(object.ModuleInfo == class))
{
    class ModuleInfo {}

    static assert(!is(object.ModuleInfo == ModuleInfo));
    static assert(__traits(classInstanceSize, object.ModuleInfo) !=
                  __traits(classInstanceSize, ModuleInfo));
}

/***************************************************/
// 11554

enum E11554;
static assert(is(E11554 == enum));

struct Bro11554(N...) {}
static assert(!is(E11554 unused : Bro11554!M, M...));
