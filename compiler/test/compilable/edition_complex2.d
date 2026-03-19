// REQUIRED_ARGS: -edition=2024
struct _Complex
{
    double re = 0;
    double im = 0;
}

enum __c_complex_double : _Complex;
alias complex = __c_complex_double;

double creal(complex z)
{
    return z.re;
}
