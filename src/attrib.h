
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

/**************************************************************/

struct AttribDeclaration : Dsymbol
{
    Array *decl;	// array of Dsymbol's

    AttribDeclaration(Array *decl);
    virtual Array *include();
    void addMember(ScopeDsymbol *s);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    char *kind();
    Dsymbol *oneMember();
    void addLocalClass(Array *);
    void toCBuffer(OutBuffer *buf);

    void toObjFile();			// compile to .obj file
    int cvMember(unsigned char *p);
};

struct StorageClassDeclaration: AttribDeclaration
{
    unsigned stc;

    StorageClassDeclaration(unsigned stc, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
};

struct LinkDeclaration : AttribDeclaration
{
    enum LINK linkage;

    LinkDeclaration(enum LINK p, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void semantic3(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    char *toChars();
};

struct ProtDeclaration : AttribDeclaration
{
    enum PROT protection;

    ProtDeclaration(enum PROT p, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
};

struct AlignDeclaration : AttribDeclaration
{
    unsigned salign;

    AlignDeclaration(unsigned sa, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
};

struct AnonDeclaration : AttribDeclaration
{
    int isunion;

    AnonDeclaration(Loc loc, int isunion, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    char *kind();
};

struct PragmaDeclaration : AttribDeclaration
{
    Array *args;		// array of Expression's

    PragmaDeclaration(Loc loc, Identifier *ident, Array *args, Array *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    char *kind();
    void toObjFile();			// compile to .obj file
};

struct DebugDeclaration : AttribDeclaration
{
    Condition *condition;
    Array *elsedecl;	// array of Dsymbol's for else block

    DebugDeclaration(Condition *condition, Array *decl, Array *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Array *include();
    void toCBuffer(OutBuffer *buf);
};

struct VersionDeclaration : DebugDeclaration
{
    VersionDeclaration(Condition *condition, Array *decl, Array *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);

    VersionDeclaration *isVersionDeclaration() { return this; }
};

#endif /* DMD_ATTRIB_H */
