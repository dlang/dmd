float fun(cfloat z)
{
    return z.re;
}

void main()
{
    cfloat[1] A;
    float[1] B;
    int i = 0;
    double C = fun(A[i] * B[i]);
}
