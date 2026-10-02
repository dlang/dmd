
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/init.h
 */

#pragma once

#include "arraytypes.h"

class Identifier;
class Expression;

enum NeedInterpret { INITnointerpret, INITinterpret };

struct Designator
{
    Expression *exp;
    Identifier *ident;
};

struct DesigInit
{
    Designators *designatorList;
    Expression *initializer;
};
