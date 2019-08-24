/*
  REQUIRED_ARGS: -transition=vfpbool -preview=fpbool
  TEST_OUTPUT:
  ---
runnable/test13489.d(7): Expression `f` implicitly converts `float` to `bool`
runnable/test13489.d(7): Expression `d` implicitly converts `double` to `bool`
runnable/test13489.d(7): Expression `r` implicitly converts `real` to `bool`
runnable/test13489.d(9): Expression `f` implicitly converts `float` to `bool`
runnable/test13489.d(11): Expression `d` implicitly converts `double` to `bool`
runnable/test13489.d(14): Expression `f` implicitly converts `float` to `bool`
runnable/test13489.d(15): Expression `d` implicitly converts `double` to `bool`
runnable/test13489.d(16): Expression `r` implicitly converts `real` to `bool`
runnable/test13489.d(19): Expression `f` implicitly converts `float` to `bool`
runnable/test13489.d(20): Expression `d` implicitly converts `double` to `bool`
runnable/test13489.d(21): Expression `r` implicitly converts `real` to `bool`
  ---
*/

#line 1
void main ()
{
    float f;
    double d;
    real r;

    if (f || d || r)
        assert(0);
    if (f)
        assert(0);
    if (!d) {}
    else assert(0);

    assert(!f);
    assert(!d);
    assert(!r);

    f = d = r = 0.0;
    assert(!f);
    assert(!d);
    assert(!r);
}
