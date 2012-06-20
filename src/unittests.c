
// Copyright (c) 2010-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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
