
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_DEBCOND_H
#define DMD_DEBCOND_H

struct Expression;
struct Identifier;
struct OutBuffer;
struct Module;
struct Scope;
struct ScopeDsymbol;
#ifdef _DH
#include "lexer.h" // dmdhg
#endif
enum TOK;
#ifdef _DH
struct HdrGenState;
#endif

int findCondition(Array *ids, Identifier *ident);

struct Condition
{
    Loc loc;
    int inc;		// 0: not computed yet
			// 1: include
			// 2: do not include

    Condition(Loc loc);

    virtual Condition *syntaxCopy() = 0;
    virtual int include(Scope *sc, ScopeDsymbol *s) = 0;
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs) = 0;
};

struct DVCondition : Condition
{
    unsigned level;
    Identifier *ident;
    Module *mod;

    DVCondition(Module *mod, unsigned level, Identifier *ident);

    Condition *syntaxCopy();
};

struct DebugCondition : DVCondition
{
    static void setGlobalLevel(unsigned level);
    static void addGlobalIdent(char *ident);
    static void addPredefinedGlobalIdent(char *ident);

    DebugCondition(Module *mod, unsigned level, Identifier *ident);

    int include(Scope *sc, ScopeDsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct VersionCondition : DVCondition
{
    static void setGlobalLevel(unsigned level);
    static void checkPredefined(Loc loc, char *ident);
    static void addGlobalIdent(char *ident);
    static void addPredefinedGlobalIdent(char *ident);

    VersionCondition(Module *mod, unsigned level, Identifier *ident);

    int include(Scope *sc, ScopeDsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct StaticIfCondition : Condition
{
    Expression *exp;

    StaticIfCondition(Loc loc, Expression *exp);
    Condition *syntaxCopy();
    int include(Scope *sc, ScopeDsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct IftypeCondition : Condition
{
    /* iftype (targ id tok tspec)
     */
    Type *targ;
    Identifier *id;	// can be NULL
    enum TOK tok;	// ':' or '=='
    Type *tspec;	// can be NULL

    IftypeCondition(Loc loc, Type *targ, Identifier *id, enum TOK tok, Type *tspec);
    Condition *syntaxCopy();
    int include(Scope *sc, ScopeDsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};


#endif
