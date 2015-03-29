// PERMUTE_ARGS:
// REQUIRED_ARGS: -o-

/***************************************************/
// 6719

pragma(msg, __traits(compiles, mixin("(const(A))[0..0]")));

/***************************************************/
// 9232

struct Foo9232
{
    void bar(T)() {}
    void baz() {}
}

void test9232()
{
    Foo9232 foo;
    (foo).bar!int();   // OK <- Error: found '!' when expecting ';' following statement
    ((foo)).bar!int(); // OK
    foo.bar!int();     // OK
    (foo).baz();       // OK
}

/***************************************************/
// 9401

struct S9401a
{
    ~this() nothrow pure @safe { }
}

struct S9401b
{
    @safe ~this() pure nothrow { }
}

void test9401() nothrow pure @safe
{
    S9401a s1;
    S9401b s2;
}

/***************************************************/
// 9649

class Outer9649
{
    class Inner
    {
    }
}

void test9649()
{
    Outer9649 outer9649;
    (outer9649).new Inner();
}
