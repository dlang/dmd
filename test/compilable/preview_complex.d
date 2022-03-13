// REQUIRED_ARGS: -preview=complex

struct cfloat
{
    float re;
    ifloat im;
}
alias ifloat = float;

struct cdouble
{
    double re;
    idouble im;
}
alias idouble = double;

struct creal
{
    real re;
    ireal im;
}
alias ireal = real;
