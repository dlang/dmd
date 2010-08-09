
#include <stdio.h>

#include "mars.h"

void unittest_speller();

void unittests()
{
#if UNITTEST
    unittest_speller();
#endif
}
