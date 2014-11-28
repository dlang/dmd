/*
TEST_OUTPUT:
---
fail_compilation/fail10439.d(18): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(19): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(20): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(22): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(23): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(24): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(26): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(27): Error: use .min_normal property instead of .min
fail_compilation/fail10439.d(28): Error: use .min_normal property instead of .min
---
*/

void main()
{
    auto a = float.min;
    auto b = double.min;
    auto c = real.min;

    auto d = ifloat.min;
    auto e = idouble.min;
    auto f = ireal.min;

    auto g = cfloat.min;
    auto h = cdouble.min;
    auto i = creal.min;
}
