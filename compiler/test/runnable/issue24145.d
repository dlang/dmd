// REQUIRED_ARGS: -inline
// PERMUTE_ARGS: -O

// Multiplication must invalidate a register previously holding a literal index.
struct Matrix
{
    size_t[2] lengths;
    double[] data;
    ~this() {}

    size_t index(size_t I)(size_t[I] indices) const
    {
        enum E = I - 1;
        assert(indices[E] < lengths[E], "INDEX FAILURE");
        ptrdiff_t ball = 1;
        ptrdiff_t stride = indices[E] * ball;
        static foreach_reverse (i; 0 .. E)
        {
            ball *= lengths[i + 1];
            assert(indices[i] < lengths[i], "INDEX FAILURE");
            stride += ball * indices[i];
        }
        return stride;
    }

    ref double opIndex(size_t I)(size_t[I] indices...)
    {
        return data[index(indices)];
    }
}

Matrix makeMatrix()()
{
    return Matrix([3, 3], new double[9]);
}

void main()
{
    { auto previous = makeMatrix(); }
    auto matrix = makeMatrix();
    foreach (i; 0 .. 9)
        matrix.data[i] = 1.0;
    assert(matrix[0, 0] == 1 && matrix[1, 0] == 1 && matrix[1, 1] == 1);
}
