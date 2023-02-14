
int  foo(int x, scope const ...);
uint bar(int x, return scope shared ...);
int  abc(int x, scope immutable ...);

//pragma(msg, foo.mangleof);
//pragma(msg, bar.mangleof);
//pragma(msg, abc.mangleof);

static assert(foo.mangleof == "_D6vararg3fooFiMxYi");
static assert(bar.mangleof == "_D6vararg3barFiMNkOYk");
static assert(abc.mangleof == "_D6vararg3abcFiMyYi");
