// PERMUTE_ARGS:


/**************************************************
   Segfault.
   http://www.digitalmars.com/d/archives/6376.html
**************************************************/

alias float[2] vector2;
typedef vector2 point2;  // if I change this typedef to alias it works fine

float distance(point2 a, point2 b)
{
  point2 d;
  d[0] = b[0] - a[0]; // if I comment out this line it won't crash
  return 0.0f;
}

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

//static assert(is(typeof(bug6661!(int).blaz)));

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
