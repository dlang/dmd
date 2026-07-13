/* The test related to https://github.com/dlang/dmd/issues/22322
 * The issue title:
 * "converting real to float uses double rounding for 64-bit code
 * causing unexpected results"
 */

pragma(inline, false)
void test22322(real r)
{
    assert(r == 0x1.000002fffffffcp-1);
    double d = r;
    assert(d == 0x1.000003p-1);
    float f = r;
    assert(f == 0x1.000002p-1);
    float fd = d;
    assert(fd == 0x1.000004p-1);
    real rd = d;
    assert(rd == 0x1.000003p-1);
    float frd = rd;
    assert(frd == 0x1.000004p-1);
}

// https://github.com/dlang/dmd/issues/18316
pragma(inline, false)
void test18316(real closest)
{
    // Approximations to pi^2, accurate to 18 digits:
    // real closest = 0x9.de9e64df22ef2d2p+0L;
    real next    = 0x9.de9e64df22ef2d3p+0L;
    assert(closest != next);

    // A literal with 23 digits maps to the correct
    // representation.
    real dig23 = 9.86960_44010_89358_61883_45L;
    assert (dig23 == closest);

    // 22 digits should also be (more than) sufficient,
    // but no...
    real dig22 = 9.86960_44010_89358_61883_5L;
    assert (dig22 == closest);  // Fails; should pass
}

// https://github.com/dlang/dmd/issues/19733
pragma(inline, false)
void test19733(real r)
{
    assert(r == 0x1FFFFFFFFFFFFFFFDp0L);
}

pragma(inline, false)
void testDenormal(real rx)
{
    enum rd = 8.4052578577802337657e-4933L;
    real r1 = rx;
    real r2 = rd;
    assert(r1 > 0);
    assert(r1 == r2);
}

void main()
{
    static if (real.mant_dig == 64)
    {
        // values must be passed to non-inlineable function to avoid "optimization" to double
        test22322(0.5000000894069671353303618843710864894092082977294921875);
        test18316(0x9.de9e64df22ef2d2p+0L);
        test19733(36893488147419103229.0L);
        testDenormal(0x1p-16384L);
    }
}
