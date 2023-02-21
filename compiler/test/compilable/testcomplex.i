
/* GCC header complex.h requires supporting `i` suffix extension
 */

_Complex float testf()
{
    _Complex float x = 1.0if;
    return x;
}

_Complex double testd()
{
    _Complex double x = 1.0i;
    return x;
}

_Complex long double testld()
{
    _Complex long double x = 1.0iL;
    return x;
}

