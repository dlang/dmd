struct Foo {
    ~this() { throw new Exception(""); }
}
nothrow void b(Foo t) {}
