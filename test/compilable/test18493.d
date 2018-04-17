// https://issues.dlang.org/show_bug.cgi?id=18493

struct S
{
    this(this) const
    {
    }

    ~this()
    {
    }
}

struct C
{
    S s1;
    S s2;
}
