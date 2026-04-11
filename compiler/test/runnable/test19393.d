string result;

struct S
{
    this(this)
    {
        result ~= "A";
    }

    ~this()
    {
        result ~= "B";
    }
}

void foo(const(S)[] ar...)
{
    assert(result == "A");
    /* postblit gets called on this initialization,
     * then when the function returns, the destructor
     * gets called, appending "B";
     */
    auto d = ar[0];
    assert(result == "AA");
}

void bar()
{
    /* S(null) needs to be destroyed after the function call,
     * that means that another `B` is appended
     */
    foo(S());
}

void main()
{
    bar();
    assert(result == "AABB");
}
