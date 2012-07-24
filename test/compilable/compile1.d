// PERMUTE_ARGS:

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

static assert(is(typeof(bug6661!(int).blaz)));

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

//static assert(!is(typeof(
//cast(bool)bug6720()
//)));

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


