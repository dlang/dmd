// PERMUTE_ARGS:
// REQUIRED_ARGS: -betterC

struct VertexA
{
    float pos;
}

struct VertexB
{
    float[2] pos;
}

extern(C) int main()
{
    float f_a;
    float f_b;
    assert(f_a != f_b);

    f_a = 0;
    assert(f_a != f_b);

    f_b = 0;
    assert(f_a == f_b);


    VertexA a_a;
    VertexA a_b;
    assert(a_a != a_b);

    a_a.pos = 0;
    assert(a_a != a_b);

    a_b.pos = 0;
    assert(a_a == a_b);

    VertexB b_a;
    VertexB b_b;
    assert(b_a != b_b);

    b_a.pos = 0;
    assert(b_a != b_b);

    b_b.pos = 0;   
    assert(b_a == b_b);

    return 0;
}
