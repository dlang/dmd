
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_ATTRIB_H
#define DMD_ATTRIB_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"

struct Expression;
struct Statement;
struct LabelDsymbol;
struct Initializer;
struct Module;
struct Condition;
#ifdef _DH
struct HdrGenState;
#endif

/**************************************************************/

struct AttribDeclaration : Dsymbol
{
    Array *decl;	// array of Dsymbol's

    AttribDeclaration(Array *decl);
    virtual Array *include(Scope *sc, ScopeDsymbol *s);
    void addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    void addComment(unsigned char *comment);
    void emitComment(Scope *sc);
    char *kind();
    Dsymbol *oneMember();
    void checkCtorConstInit();
    void addLocalClass(Array *);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    AttribDeclaration *isAttribDeclaration() { return this; }

    void toObjFile();			// compile to .obj file
    int cvMember(unsigned char *p);
};

struct StorageClassDeclaration: AttribDeclaration
{
    unsigned stc;

    StorageClassDeclaration(unsigned stc, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct LinkDeclaration : AttribDeclaration
{
    enum LINK linkage;

    LinkDeclaration(enum LINK p, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void semantic3(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *toChars();
};

struct ProtDeclaration : AttribDeclaration
{
    enum PROT protection;

    ProtDeclaration(enum PROT p, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct AlignDeclaration : AttribDeclaration
{
    unsigned salign;

    AlignDeclaration(unsigned sa, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct AnonDeclaration : AttribDeclaration
{
    int isunion;

    AnonDeclaration(Loc loc, int isunion, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();
};

struct PragmaDeclaration : AttribDeclaration
{
    Array *args;		// array of Expression's

    PragmaDeclaration(Loc loc, Identifier *ident, Array *args, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();
    void toObjFile();			// compile to .obj file
};

struct ConditionalDeclaration : AttribDeclaration
{
    Condition *condition;
    Array *elsedecl;	// array of Dsymbol's for else block

    ConditionalDeclaration(Condition *condition, Array *decl, Array *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Dsymbol *oneMember();
    Array *include(Scope *sc, ScopeDsymbol *s);
    void addComment(unsigned char *comment);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct StaticIfDeclaration : ConditionalDeclaration
{
    ScopeDsymbol *sd;
    int addisdone;

    StaticIfDeclaration(Condition *condition, Array *decl, Array *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void semantic(Scope *sc);
};

#endif /* DMD_ATTRIB_H */
