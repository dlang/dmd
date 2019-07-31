float getreal(cfloat z)
{
    return z.re;
}
float geti(cfloat z)
{
     return z.im;
}

void main()
{
    cfloat[1] A;
    float[1] B;
    int i = 0;
    A[0] = 2.0f + 4i;
    B[0] = 3.0f;
    assert(((2.0f + 4i) * 3.0f).re == getreal(A[i] * B[i]));
    //assert(((2.0f + 4i) * 3.0f).im == geti(A[i] * B[i]));
    double C = getreal(A[i] * B[i]);
}
