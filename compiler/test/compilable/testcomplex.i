
/* GCC header complex.h requires supporting `i` suffix extension
 */

_Complex float testf()
{
    _Complex float x = 1.0if;
    return x;
}

_Complex float testf2()
{
    _Complex float x = (float _Complex)1.0i;
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

_Complex float testcast()
{
    _Complex double y = 1.0i;
    return (_Complex float)y;
}

_Static_assert((float _Complex)1.0i == 1.0i, "1");
