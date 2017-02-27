// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.hooks;

import ddmd.dscope;
import ddmd.expression;

Expression semanticTraitsHook(TraitsExp e, Scope* sc)
{
    return null;
}
