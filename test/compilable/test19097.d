/* REQUIRED_ARGS: -dip1000
 */

// Related to: https://github.com/dlang/dmd/pull/8504

@safe:

void betty()(ref int* r, return scope int* p)
{
    r = p; // infer `scope` for r
}

void foo(scope int* pf)
{
    scope int* rf;
    betty(rf, pf);
}
