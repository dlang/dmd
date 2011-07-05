
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
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
struct DebugCondition;
#include "lexer.h" // dmdhg
enum TOK;
struct HdrGenState;

int findCondition(Strings *ids, Identifier *ident);

struct Condition
{
    Loc loc;
    int inc;            // 0: not computed yet
                        // 1: include
                        // 2: do not include

    Condition(Loc loc);

    virtual Condition *syntaxCopy() = 0;
    virtual int include(Scope *sc, ScopeDsymbol *s) = 0;
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs) = 0;
    virtual DebugCondition *isDebugCondition() { return NULL; }
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
    static void addGlobalIdent(const char *ident);
    static void addPredefinedGlobalIdent(const char *ident);

    DebugCondition(Module *mod, unsigned level, Identifier *ident);

    int include(Scope *sc, ScopeDsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    DebugCondition *isDebugCondition() { return this; }
};

struct VersionCondition : DVCondition
{
    static void setGlobalLevel(unsigned level);
    static void checkPredefined(Loc loc, const char *ident);
    static void addGlobalIdent(const char *ident);
    static void addPredefinedGlobalIdent(const char *ident);

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
    Identifier *id;     // can be NULL
    enum TOK tok;       // ':' or '=='
    Type *tspec;        // can be NULL

    IftypeCondition(Loc loc, Type *targ, Identifier *id, enum TOK tok, Type *tspec);
    Condition *syntaxCopy();
    int include(Scope *sc, ScopeDsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};


#endif
