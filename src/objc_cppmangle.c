
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_cppmangle.c
 */

#include "objc.h"
#include "outbuffer.h"

void objc_CppMangleVisitor_visit_TypeObjcSelector(OutBuffer &buf, TypeObjcSelector *t)
{
    buf.writestring("P13objc_selector");
}
