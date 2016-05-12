// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.appl;

import ddmd.dscope;
import ddmd.expression;

struct Hooks
{
    Expression function(TraitsExp e, Scope* sc) semanticTraits;
}

void setHooks(Hooks hooks)
{
    .hooks = hooks;
}

Expression semanticTraitsHook(TraitsExp e, Scope* sc)
{
    if (hooks.semanticTraits)
        return hooks.semanticTraits(e, sc);
    return null;
}

package:

__gshared Hooks hooks;
