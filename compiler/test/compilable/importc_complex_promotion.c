// Ensure complex float can be implicitly promoted to complex double
// Fixes issue #22259
#include <complex.h>

void testComplexPromotion()
{
    _Complex float yf = 1.0if;
    _Complex double x = yf;              // promotion: _Complex float -> _Complex double
}

void testComplexPreservation()
{
    // These should still work (no change)
    _Complex float f1 = 1.0f + 1.0if;
    _Complex float f2 = 1.0if + 2.0if;
    _Complex double d1 = 1.0 + 2.0i;
    _Complex double d2 = 2.0 + 3.0i;
}

int main()
{
    testComplexPromotion();
    testComplexPreservation();
    return 0;
}
