float fun(cfloat z)
{
    return z.re;
}

void main()
{
    cfloat[1] A;
    float[1] B;
    int i = 0;
    version(D_LP64) {} else // disabled because of wrong codegen: https://issues.dlang.org/show_bug.cgi?id=20089
    double C = fun(A[i] * B[i]);
}
