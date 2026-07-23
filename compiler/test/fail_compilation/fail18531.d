/*
TEST_OUTPUT:
---
fail_compilation/fail18531.d(16): Error: comparison with `float.nan` is always false; use `is` instead
fail_compilation/fail18531.d(18): Error: comparison with `float.nan` is always true; use `!is` instead
fail_compilation/fail18531.d(20): Error: comparison with `float.nan` is always false; use `is` instead
fail_compilation/fail18531.d(22): Error: comparison with `double.nan` is always false; use `is` instead
---
*/

enum myNaN = double.nan;

void main()
{
    float a = float.nan;
    assert(a == float.nan);
    float b = 0.0;
    assert(b != float.nan);
    float c = float.init;
    assert(c == float.init);
    assert(a == c);
    assert(myNaN == double.nan);
}
