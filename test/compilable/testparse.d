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
