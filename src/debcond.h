
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

struct Expression;
struct Identifier;
struct OutBuffer;

struct Condition
{
    unsigned level;
    Identifier *ident;

    Condition(unsigned level, Identifier *ident);

    virtual int include();
    int isBool(int result);
    Expression *toExpr();
    void toCBuffer(OutBuffer *buf);
};

struct DebugCondition : Condition
{
    static void setLevel(unsigned level);
    static void addIdent(char *ident);

    DebugCondition(unsigned level, Identifier *ident);

    int include();
};

struct VersionCondition : Condition
{
    static void setLevel(unsigned level);
    static void addIdent(char *ident);

    VersionCondition(unsigned level, Identifier *ident);

    int include();
};

