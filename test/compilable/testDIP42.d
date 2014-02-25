// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

// enum ident(tpl) = Initializer;

enum isIntegral(T) = is(T == int) || is(T == long);
static assert( isIntegral!int);
static assert( isIntegral!long);
static assert(!isIntegral!double);
static assert(!isIntegral!(int[]));

version(none)
{
enum
    allSatisfy(alias pred, TL...) =
        TL.length == 0 || (pred!(TL[0]) && allSatisfy!(pred, TL[1..$])),
    anySatisfy(alias pred, TL...) =
        TL.length != 0 && (pred!(TL[0]) || anySatisfy!(pred, TL[1..$])) || false;
static assert( allSatisfy!(isIntegral, int, long));
static assert(!allSatisfy!(isIntegral, int, double));
static assert( anySatisfy!(isIntegral, int, double));
static assert(!anySatisfy!(isIntegral, int[], double));
}

void test1()
{
    // statement
    enum isIntegral2(T) = is(T == int) || is(T == long);
    static assert(isIntegral2!int);
}

/******************************************/
// alias ident(tpl) = Type;

alias TypeTuple(TL...) = TL;
static assert(is(TypeTuple!(int, long)[0] == int));
static assert(is(TypeTuple!(int, long)[1] == long));

alias Id(T) = T, Id(alias A) = A;
static assert(is(Id!int == int));
static assert(__traits(isSame, Id!TypeTuple, TypeTuple));

void test2()
{
    // statement
    alias TypeTuple2(TL...) = TL;
    static assert(is(TypeTuple2!(int, long)[0] == int));
    static assert(is(TypeTuple2!(int, long)[1] == long));

    alias IdT(T) = T, IdA(alias A) = A;
    static assert(is(IdT!int == int));
    static assert(__traits(isSame, IdA!TypeTuple, TypeTuple));
}

/******************************************/
// template variable declaration

enum bool isFloatingPoint(T) = is(T == float) || is(T == double);
static assert( isFloatingPoint!double);
static assert(!isFloatingPoint!string);

void main()
{
    enum bool isFloatingPoint2(T) = is(T == float) || is(T == double);
    static assert( isFloatingPoint2!double);
    static assert(!isFloatingPoint2!string);
}
