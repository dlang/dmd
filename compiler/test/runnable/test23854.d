// https://github.com/dlang/dmd/issues/23854

void main()
{
    int[4] a = [1, -2, 3, -4];

    int[4] b = +a[];
    assert(b == [1, -2, 3, -4]);

    int[4] c;
    c[] = +a[] * 2;
    assert(c == [2, -4, 6, -8]);

    c[] = -(+a[]);
    assert(c == [-1, 2, -3, 4]);

    double[] d = [0.5, -1.5];
    double[2] e;
    e[] = +d[] + 1;
    assert(e == [1.5, -0.5]);
}
