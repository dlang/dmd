// PERMUTE_ARGS:
// REQUIRED_ARGS: -betterC

struct VertexA(T)
{
    T pos;
}

struct VertexB(T)
{
    T[2] pos;
}

void test(T)()
{
    T f_a;
    T f_b;
    assert(f_a != f_b);

    f_a = 0;
    assert(f_a != f_b);

    f_b = 0;
    assert(f_a == f_b);


    VertexA!T a_a;
    VertexA!T a_b;
    assert(a_a != a_b);

    a_a.pos = 0;
    assert(a_a != a_b);

    a_b.pos = 0;
    assert(a_a == a_b);

    VertexB!T b_a;
    VertexB!T b_b;
    assert(b_a != b_b);

    b_a.pos = 0;
    assert(b_a != b_b);

    b_b.pos = 0;   
    assert(b_a == b_b);
}

extern(C) int main()
{
    test!(float)();
    test!(double)();
    test!(real)();

    return 0;
}

extern(C) void _memset80(real* reals, real value, size_t length)
{
    for (size_t i = 0; i < length; ++i)
        reals[i] = value;
}
