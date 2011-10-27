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

void main()
{
    test1();
    test2();
}
