// REQUIRED_ARGS: -mcpu=avx2
import core.simd;

version (D_AVX)
{
    double4 foo();
    void test(double[4]);

    void main()
    {
        test(foo().array);
    }
}
