/*
FIXME: Older 32-bit DMD host compilers with faulty optimization
lead to unfortunate test failures, see
https://github.com/dlang/dmd/pull/6831#issuecomment-304495842.

DISABLED: win32 win64 linux freebsd32
*/

/*
TEST_OUTPUT:
---
fail_compilation/impconv.d(24): Error: function `impconv.foo_float(float)` is not callable using argument types `(int)`
fail_compilation/impconv.d(30): Error: function `impconv.foo_double(double)` is not callable using argument types `(long)`
---
*/

void foo_float(float);
void foo_double(double);
void foo_real(real);

void main()
{
    foo_float(1);        // implicitly convertible to float
    foo_float(-int.max); // -(2^31 - 1)
    // FIXME: Unsigned constants don't produce an error,
    // see https://issues.dlang.org/show_bug.cgi?id=17436.
    //foo_float(uint.max); // 2^32 - 1

    foo_double(int.max);   // implicitly convertible to double
    foo_double(-long.max); // -(2^63 - 1)
    //foo_double(ulong.max); // 2^64 - 1

    foo_real(0xffff_ffff_ffffL); // 2^48 - 1, implicitly convertible to real
    static assert(__traits(compiles, foo_real(-long.max)) == (real.mant_dig >= 63));
    static assert(__traits(compiles, foo_real(ulong.max)) == (real.mant_dig >= 64));
}
