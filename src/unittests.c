
#include <stdio.h>

#include "mars.h"

void unittest_speller();
void unittest_importHint();
void unittest_aa();

void unittests()
{
#if UNITTEST
    unittest_speller();
    unittest_importHint();
    unittest_aa();
#endif
}
