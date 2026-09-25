module enum_union_scoping;

// Test member function inside a local enum union
void testLocalMemberFactory()
{
    enum union LocalPacket
    {
        case Data(int);

        int value() { return 42; }

        case Ping(long);
    }

    assert(LocalPacket.Data(1).value() == 42);
    assert(LocalPacket.Ping(2).value() == 42);
}

// Test alias variant inside with-statement
alias None = typeof(null);

enum union Option(T)
{
    case None = typeof(null);
    case Some = T;
}

void testAliasVariantWith()
{
    Option!string qualified = Option!string.Some("asdf");
    with (Option!string)
    {
        Option!string unqualified = Some("asdf");
        assert(unqualified.__tag == qualified.__tag);
    }
}

void main()
{
    testLocalMemberFactory();
    testAliasVariantWith();
}
