import core.stdc.stdio;

pragma(inline, true)
double sqrt(double x)
{
    static import core.math;
    return core.math.sqrt(x);
}

shared static this()
{
    double q = -5.0;
    double r = q + 1.0;
    double result = sqrt(-r);
    //printf("%f\n", result);
    assert(result == 2);
}
