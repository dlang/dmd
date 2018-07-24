module test19065;

struct S
{
    bool b = false;

    invariant
    {
        assert(b == true);
    }

    @disable this();
    @safe this(int)
    {
        b = true;
    }

    // Invariant may be violated in the destructor.
    // This is because `this` may also be S.init.
    // For this reason, the invariant must not be checked on struct entry.
    @safe ~this()
    {
    }
}

@safe void main()
{
    S s = S.init;
}
