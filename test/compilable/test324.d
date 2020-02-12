struct Foo
{
    void doStuff(alias fun)() {}
}

void main()
{
    Foo foo;
    foo.doStuff!( (i) { return i; })();
}
