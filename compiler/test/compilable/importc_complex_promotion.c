// Ensure complex float can be implicitly promoted to complex double
// Fixes issue #22259

#include <complex.h>

void testComplexPromotion()
{
    // Basic case from issue #22259
    _Complex double x = 1 + 1.0if;
    
    // Float imaginary with int
    _Complex double y = 2 + 3.0if;
    
    // Two float complex values
    _Complex double z = 1.0if + 2.0if;
    
    // Mixed real and float imaginary
    _Complex double w = 5.0 + 1.0if;
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
