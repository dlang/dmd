extern (C) int printf(const(char*) fmt, ...);

alias typeof(null) null_t;

/**********************************************/

void test1()
{
    null_t null1;
    typeof(null) null2;

    static assert(is(typeof(null1) == typeof(null)));
    static assert(is(typeof(null2) == typeof(null)));

    static assert(is(typeof(null1) == null_t));
    static assert(is(typeof(null2) == null_t));
}

/**********************************************/

interface I{}
class C{}

int f(null_t)   { return 1; }
int f(int[])    { return 2; }
int f(C)        { return 3; }

void test2()
{
    static assert(is(null_t : C));
    static assert(is(null_t : I));
    static assert(is(null_t : int[]));
    static assert(is(null_t : void*));
    static assert(is(null_t : int**));

    static assert(!is(null_t == C));
    static assert(!is(null_t == I));
    static assert(!is(null_t == int[]));
    static assert(!is(null_t == void*));
    static assert(!is(null_t == int**));

    static assert(is(null_t == null_t));

    assert(f(null) == 1);
}

/**********************************************/
// 5899

auto f5899(bool b)
{
    if (b)
        return new Object;
    else
        return null;
}
static assert(is(typeof(f5899) R == return) && is(R == Object));
pragma(msg, typeof(f5899));

auto g5899(bool b)
{
    if (b)
        return new int;
    else
        return null;
}
static assert(is(typeof(g5899) R == return) && is(R == int*));
pragma(msg, typeof(g5899));

auto h5899(bool b)
{
    if (b)
        return [1];
    else
        return null;
}
static assert(is(typeof(h5899) R == return) && is(R == int[]));
pragma(msg, typeof(h5899));

/**********************************************/

void main()
{
    test1();
    test2();
}
