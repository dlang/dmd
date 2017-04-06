// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.hooks;

import ddmd.dscope;
import ddmd.expression;

import gen.ldctraits;

/// Returns `null` when the __trait was not recognized.
Expression semanticTraitsHook(TraitsExp e, Scope* sc)
{
    return semanticTraitsLDC(e, sc);
}
