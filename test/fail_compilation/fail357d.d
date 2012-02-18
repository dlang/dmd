void fail357()
{
    // symbol collision
    import imports.fail357b : Foo;
    import imports.fail357c : Foo;

    static if (__traits(compiles, () { Foo foo; }))
        pragma(msg, "FAILING TEST");
    static assert(0);
}
