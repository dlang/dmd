// REQUIRED_ARGS: -o-
// PERMUTE_ARGS:

struct Foo
{
    void bar(T)() {}
    void baz() {}
}

void main()
{
    Foo foo;
    (foo).bar!int();   // Error: found '!' when expecting ';' following statement
    ((foo)).bar!int(); // OK
    foo.bar!int();     // OK
    (foo).baz();       // OK
}
