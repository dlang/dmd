
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
    int hdrgen;         // 1 if generating header file
    int ddoc;           // 1 if generating Ddoc file
    int console;        // 1 if writing to console
    int tpltMember;
    int inCallExp;
    int inPtrExp;
    int inSlcExp;
    int inDotExp;
    int inBinExp;
    int inArrExp;
    int emitInst;
    int autoMember;
    bool fullQualification; // fully qualify types when printing

    struct
    {
        int init;
        int decl;
    } FLinit;
    Scope* scope;       // Scope when generating ddoc

    HdrGenState() { memset(this, 0, sizeof(HdrGenState)); }
};

void functionToBufferFull(TypeFunction *tf, OutBuffer *buf, Identifier *ident, HdrGenState* hgs, TemplateDeclaration *td);
