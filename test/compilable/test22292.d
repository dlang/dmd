// https://issues.dlang.org/show_bug.cgi?id=22292

// Original case

class C1
{
    C1 c1;
    this () pure
    {
        c1 = this;
    }
}
immutable x = cast(immutable)r;

auto r()
{
    C1 c1 = new C1;
    return c1;
}

// Reference stored in another class

template Test2()
{
    class C1
    {
        C2 c2;
        this () pure
        {
            C1 a = this;
            c2 = new C2(a);
        }
    }
    class C2
    {
        C1 c1;
        this (C1 c) pure
        {
            c1 = c;
        }
    }
    immutable x = cast(immutable)r;

    auto r()
    {
        C1 c1 = new C1();
        return c1;
    }
}

alias test2 = Test2!();

// Ditto but using a struct in the middle

template Test3()
{
    class C0
    {
        S1 s1;

        this()
        {
            s1 = S1(this);
        }
    }
    struct S1
    {
        C1 c1;
        this (C0 c)
        {
            c1 = new C1(c);
        }
    }
    class C1
    {
        C0 c0;
        this(C0 c)
        {
            c0 = c;
        }
    }
    immutable x = cast(immutable)r;

    auto r()
    {
        C0 c0 = new C0();
        return c0;
    }
}

alias test3 = Test3!();
