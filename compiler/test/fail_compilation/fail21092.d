// https://issues.dlang.org/show_bug.cgi?id=21092

/*
TEST_OUTPUT:
---
fail_compilation/fail21092.d(31): Error: using the result of a comma expression is not allowed
    *(T, U);
      ^
fail_compilation/fail21092.d(31): Error: using `*` on an array is no longer supported; use `*(T , U).ptr` instead
    *(T, U);
    ^
fail_compilation/fail21092.d(31): Error: `*(T , cast(real*)U)` has no effect
    *(T, U);
    ^
fail_compilation/fail21092.d(38): Error: using the result of a comma expression is not allowed
    *(w, SmallStirlingCoeffs);
      ^
fail_compilation/fail21092.d(38): Error: using `*` on an array is no longer supported; use `*(w , SmallStirlingCoeffs).ptr` instead
    *(w, SmallStirlingCoeffs);
    ^
fail_compilation/fail21092.d(38): Error: `*(w , cast(real*)SmallStirlingCoeffs)` has no effect
    *(w, SmallStirlingCoeffs);
    ^
---
*/

real[] T;
real[] U = [];
real erf()
{
    *(T, U);
}

real gammaStirling()
{
    static real[] SmallStirlingCoeffs = [];
    real w;
    *(w, SmallStirlingCoeffs);
}
