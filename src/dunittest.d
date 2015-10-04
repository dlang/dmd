// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.dunittest;

import ddmd.root.aav;
import ddmd.root.speller;
import ddmd.imphint;

extern (C++) void unittests()
{
    version (unittest)
    {
        unittest_speller();
        unittest_importHint();
        unittest_aa();
    }
}
