
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
    bool fullQual;      // fully qualify types when printing
    int tpltMember;
    int autoMember;
    int forStmtInit;

    HdrGenState() { memset(this, 0, sizeof(HdrGenState)); }
};

void toCBuffer(Statement *s, OutBuffer *buf, HdrGenState *hgs);
void toCBuffer(Type *t, OutBuffer *buf, Identifier *ident, HdrGenState *hgs);
void toCBuffer(Dsymbol *s, OutBuffer *buf, HdrGenState *hgs);
void toCBuffer(Initializer *iz, OutBuffer *buf, HdrGenState *hgs);
void toCBuffer(Expression *e, OutBuffer *buf, HdrGenState *hgs);
void toCBuffer(TemplateParameter *tp, OutBuffer *buf, HdrGenState *hgs);

void toCBufferInstance(TemplateInstance *ti, OutBuffer *buf, bool qualifyTypes = false);

void functionToBufferFull(TypeFunction *tf, OutBuffer *buf, Identifier *ident, HdrGenState* hgs, TemplateDeclaration *td);
void functionToBufferWithIdent(TypeFunction *t, OutBuffer *buf, const char *ident);

void argExpTypesToCBuffer(OutBuffer *buf, Expressions *arguments);

void arrayObjectsToBuffer(OutBuffer *buf, Objects *objects);

const char *parametersTypeToChars(Parameters *parameters, int varargs);

const char *linkageToChars(LINK linkage);
