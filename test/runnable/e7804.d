module e7804;

struct Bar {static struct B{}}
alias BarB = __traits(getMember, Bar, "B");
static assert(is(BarB == Bar.B));
static assert(is(const(__traits(getMember, Bar, "B")) == const(Bar.B)));


struct Foo {alias MyInt = int;}
alias FooInt = __traits(getMember, Foo, "MyInt");
static immutable FooInt fi = 42;
static assert(fi == 42);
void declVsStatementSupport()
{
    __traits(getMember, Foo, "MyInt") i1;
    const(__traits(getMember, Foo, "MyInt")) i2;
}



enum __traits(getMember, Foo, "MyInt") a0 = 12;
static assert(is(typeof(a0) == int));
static assert(a0 == 12);


const __traits(getMember, Foo, "MyInt") a1 = 46;
static this(){assert(a1 == 46);}


__traits(getMember, Foo, "MyInt") a2 = 78;
static this(){assert(a2 == 78);}


const(__traits(getMember, Foo, "MyInt")) a3 = 63;
static this(){assert(a3 == 63);}


struct WithSym {static int foo; static int bar(){return 42;}}
alias m1 = __traits(getMember, WithSym, "foo");
alias m2 = WithSym.foo;
static assert(__traits(isSame, m1, m2));
alias f1 = __traits(getMember, WithSym, "bar");
alias f2 = WithSym.bar;
static assert(__traits(isSame, f1, f2));


void main(){}
