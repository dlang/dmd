module e7804;

struct Bar {static struct B{}}
alias BarB = __traits(getMember, Bar, "B");
static assert(is(BarB == Bar.B));
static assert(is(const(__traits(getMember, Bar, "B")) == const(Bar.B)));


struct Foo {alias MyInt = int;}
alias FooInt = __traits(getMember, Foo, "MyInt");
static immutable FooInt fi = 42;
static assert(fi == 42);


enum __traits(getMember, Foo, "MyInt") a0 = 12;
static assert(is(typeof(a0) == int));
static assert(a0 == 12);


const __traits(getMember, Foo, "MyInt") a1 = 46;
static this(){assert(a1 == 46);}


__traits(getMember, Foo, "MyInt") a2 = 78;
static this(){assert(a2 == 78);}


const(__traits(getMember, Foo, "MyInt")) a3 = 63;
static this(){assert(a3 == 63);}


void main(){}
