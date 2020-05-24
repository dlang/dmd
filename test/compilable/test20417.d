// https://issues.dlang.org/show_bug.cgi?id=20417

struct A { ~this() @system; }
void f(A, int) @system;
A a() @system;
int i() @system;

static assert(__traits(compiles, { f(a, i); }));
static assert(__traits(compiles, f(a, i)));

static assert(is(typeof({ f(a, i); })));
static assert(is(typeof(f(a, i))));
