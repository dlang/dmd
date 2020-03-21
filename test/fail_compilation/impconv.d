/*
TEST_OUTPUT:
---
fail_compilation/impconv.d(22): Error: function `impconv.foo_float(float)` is not callable using argument types `(int)`
fail_compilation/impconv.d(22):        cannot pass argument `-2147483647` of type `int` to parameter `float`
fail_compilation/impconv.d(23): Error: function `impconv.foo_float(float)` is not callable using argument types `(uint)`
fail_compilation/impconv.d(23):        cannot pass argument `4294967295u` of type `uint` to parameter `float`
fail_compilation/impconv.d(26): Error: function `impconv.foo_double(double)` is not callable using argument types `(long)`
fail_compilation/impconv.d(26):        cannot pass argument `-9223372036854775807L` of type `long` to parameter `double`
fail_compilation/impconv.d(27): Error: function `impconv.foo_double(double)` is not callable using argument types `(ulong)`
fail_compilation/impconv.d(27):        cannot pass argument `18446744073709551615LU` of type `ulong` to parameter `double`
---
*/

void foo_float(float);
void foo_double(double);
void foo_real(real);

void main()
{
    foo_float(1);        // implicitly convertible to float
    foo_float(-int.max); // -(2^31 - 1)
    foo_float(uint.max); // 2^32 - 1

    foo_double(int.max);   // implicitly convertible to double
    foo_double(-long.max); // -(2^63 - 1)
    foo_double(ulong.max); // 2^64 - 1

    foo_real(0xffff_ffff_ffffL); // 2^48 - 1, implicitly convertible to real
    static assert(__traits(compiles, foo_real(-long.max)) == (real.mant_dig >= 63));
    static assert(__traits(compiles, foo_real(ulong.max)) == (real.mant_dig >= 64));
}
