/*
TEST_OUTPUT:
---
fail_compilation/fail18531.d(16): Error: comparison with `nanF` is always false; use `std.math.isNaN` or `is` instead
fail_compilation/fail18531.d(18): Error: comparison with `nanF` is always true; use `!std.math.isNaN` or `!is` instead
fail_compilation/fail18531.d(20): Error: comparison with `nanF` is always false; use `std.math.isNaN` or `is` instead
fail_compilation/fail18531.d(21): Error: comparison with `nan` is always false; use `std.math.isNaN` or `is` instead
---
*/

enum myNaN = double.nan;

void main()
{
    float x1 = float.nan;
    assert(x1 == float.nan);
    float x2 = 0.0;
    assert(x2 != float.nan);
    float x3 = float.init;
    assert(x3 == float.init);
    assert(myNaN == double.nan);
}
