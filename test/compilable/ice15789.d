struct InputRange {}

auto md5Of(T...)(T ) {}

template fqnSym(alias T : X!A, alias X, A...)
{
    template fqnTuple(B) { enum fqnTuple = 1; }
    enum fqnSym = fqnTuple!A;
}

void foobar()  // ICE issue 15789
{
    md5Of(InputRange());
    auto i = fqnSym!(md5Of!InputRange);
}

void barfoo()  // Reverse order was OK
{
    auto i = fqnSym!(md5Of!InputRange);
    md5Of(InputRange());
}
