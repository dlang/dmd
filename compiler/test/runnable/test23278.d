// https://github.com/dlang/dmd/issues/23278

float[2][2] f()
{
    return [[0.25f, 0.5f], [0.75f, 1.00f]];
}

void main()
{
    const float[2][2] c = f();
    assert(c[0][0] == 0.25f);
    assert(c[0][1] == 0.50f);
    assert(c[1][0] == 0.75f);
    assert(c[1][1] == 1.00f);
}
