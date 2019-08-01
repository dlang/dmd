float getreal_rcx(cfloat z)
{
    return z.re;
}
float getimag_rcx(cfloat z)
{
    return z.im;
}

float getreal_rdx(cfloat z, int)
{
    return z.re;
}
float getimag_rdx(cfloat z, int)
{
    return z.im;
}

float getreal_r8(cfloat z, int, int)
{
    return z.re;
}
float getimag_r8(cfloat z, int, int)
{
    return z.im;
}

float getreal_r9(cfloat z, int, int, int)
{
    return z.re;
}
float getimag_r9(cfloat z, int, int, int)
{
    return z.im;
}

float getreal_stack(cfloat z, int, int, int, int)
{
    return z.re;
}
float getimag_stack(cfloat z, int, int, int, int)
{
    return z.im;
}

void test18772()
{
    cfloat[1] A;
    float[1] B;
    int i = 0;
    A[0] = 2.0f + 4i;
    B[0] = 3.0f;
    assert(6.0 == getreal_rcx(A[i] * B[i]));
    assert(12.0 == getimag_rcx(A[i] * B[i]));

    assert(6.0 == getreal_rdx(A[i] * B[i], 1));
    assert(12.0 == getimag_rdx(A[i] * B[i], 1));

    assert(6.0 == getreal_r8(A[i] * B[i], 1, 2));
    assert(12.0 == getimag_r8(A[i] * B[i], 1, 2));

    assert(6.0 == getreal_r9(A[i] * B[i], 1, 2, 3));
    assert(12.0 == getimag_r9(A[i] * B[i], 1, 2, 3));

    assert(6.0 == getreal_stack(A[i] * B[i], 1, 2, 3, 4));
    assert(12.0 == getimag_stack(A[i] * B[i], 1, 2, 3, 4));
}

void test(T)()
{
    static auto getre0(T z)
    {
        return z.re;
    }
    static auto getim0(T z)
    {
        return z.im;
    }
    
    T z = 3 + 4i;
    auto d = z.re;
    
    assert(getre0(d * z) == d * 3);
    assert(getim0(d * z) == d * 4);
}

void main()
{
    test18772();

    version(none) // failing
        test!cfloat();
    test!cdouble();
    test!creal();
}
