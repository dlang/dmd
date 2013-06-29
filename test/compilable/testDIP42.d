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

// alias ident(tpl) = Type;

alias TypeTuple(TL...) = TL;
static assert(is(TypeTuple!(int, long)[0] == int));
static assert(is(TypeTuple!(int, long)[1] == long));

alias Id(T) = T, Id(alias A) = A;
static assert(is(Id!int == int));
static assert(__traits(isSame, Id!TypeTuple, TypeTuple));
