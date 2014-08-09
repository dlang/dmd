
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Dave Fladebo
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/expression.h
 */

#include <string.h>                     // memset()

void genhdrfile(Module *m);

struct HdrGenState
{
    bool hdrgen;        // true if generating header file
    bool ddoc;          // true if generating Ddoc file
    bool console;       // true if writing to console
    bool fullQual;      // fully qualify types when printing
    int tpltMember;
    int autoMember;

    struct
    {
        int init;
    } FLinit;

    HdrGenState() { memset(this, 0, sizeof(HdrGenState)); }
};

void functionToBufferFull(TypeFunction *tf, OutBuffer *buf, Identifier *ident, HdrGenState* hgs, TemplateDeclaration *td);
