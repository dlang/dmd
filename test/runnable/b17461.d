// PERMUTE_ARGS:

void t()
{
    auto a = A(B().p ? B() : B());
}

struct A
{
    int p;
}

struct B
{
    int p = 42;
    alias p this;

    ~this()
    {
        import std.conv: text;
        assert(p == 42, text(p)); /* fails; prints "1234567890" */
    }
}

void main()
{
    stomp();
    t();
}

void stomp() { int[5] stomper = 1234567890; }
