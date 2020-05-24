// REQUIRED_ARGS: -mcpu=avx2
import core.simd;

version (D_AVX)
{
    double4 foo() @system;
    void test(double[4]) @system;

    void main()
    {
        test(foo().array);
    }
}
