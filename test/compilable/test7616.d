module test7616;

@safe pure nothrow @nogc:
struct Test
{
    void bar() {}
    void staticBar() {}
}

static assert(is(typeof(&Test.init.bar) == void delegate() @safe pure nothrow @nogc));
static assert(is(typeof(&Test.staticBar) == void function() @safe pure nothrow @nogc));
