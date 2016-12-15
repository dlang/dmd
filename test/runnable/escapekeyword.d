module escapekeyword;

void staticTests()
{
    enum #body = 0;
    static assert(#body == 0);
    enum #function = 1;
    static assert(#function == 1);
    enum #void = 2;
    static assert(#void == 2);

    static assert(#void == #function + 1);
    static assert(#void == #body + 2);
}

void main()
{
    string #delegate;
    #delegate = __traits(identifier, #delegate);
    assert(#delegate == "delegate");
}
