
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_argtypes.c
 */

#include "objc.h"

TypeTuple * objc_toArgTypesVisit (TypeObjcSelector*)
{
    return new TypeTuple();     // pass on the stack for efficiency
}
