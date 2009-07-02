
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_DEBCOND_H
#define DMD_DEBCOND_H

struct Expression;
struct Identifier;
struct OutBuffer;
struct Module;

struct Condition
{
    unsigned level;
    Identifier *ident;
    Module *mod;

    Condition(Module *mod, unsigned level, Identifier *ident);

    virtual int include();
    int isBool(int result);
    Expression *toExpr();
    void toCBuffer(OutBuffer *buf);
};

struct DebugCondition : Condition
{
    static void setGlobalLevel(unsigned level);
    static void addGlobalIdent(char *ident);
    static void addPredefinedGlobalIdent(char *ident);

    DebugCondition(Module *mod, unsigned level, Identifier *ident);

    int include();
};

struct VersionCondition : Condition
{
    static void setGlobalLevel(unsigned level);
    static void checkPredefined(char *ident);
    static void addGlobalIdent(char *ident);
    static void addPredefinedGlobalIdent(char *ident);

    VersionCondition(Module *mod, unsigned level, Identifier *ident);

    int include();
};

#endif /* DMD_DEBCOND_H */
