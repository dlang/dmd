
// Copyright (c) 1999-2005 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "root.h"

#include "identifier.h"
#include "dsymbol.h"
#include "cond.h"
#include "version.h"
#include "module.h"

/* ================================================== */

/* DebugSymbol's happen for statements like:
 *      debug = identifier;
 *      debug = integer;
 */

DebugSymbol::DebugSymbol(Loc loc, Identifier *ident)
    : Dsymbol(ident)
{
    this->loc = loc;
}

DebugSymbol::DebugSymbol(Loc loc, unsigned level)
    : Dsymbol()
{
    this->level = level;
    this->loc = loc;
}

Dsymbol *DebugSymbol::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    DebugSymbol *ds = new DebugSymbol(loc, ident);
    ds->level = level;
    return ds;
}

int DebugSymbol::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    //printf("DebugSymbol::addMember('%s') %s\n", sd->toChars(), toChars());
    Module *m;

    // Do not add the member to the symbol table,
    // just make sure subsequent debug declarations work.
    m = sd->isModule();
    if (ident)
    {
        if (!m)
            error("declaration must be at module level");
        else
        {
            if (findCondition(m->debugidsNot, ident))
                error("defined after use");
            if (!m->debugids)
                m->debugids = new Strings();
            m->debugids->push(ident->toChars());
        }
    }
    else
    {
        if (!m)
            error("level declaration must be at module level");
        else
            m->debuglevel = level;
    }
    return 0;
}

void DebugSymbol::semantic(Scope *sc)
{
    //printf("DebugSymbol::semantic() %s\n", toChars());
}

void DebugSymbol::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("debug = ");
    if (ident)
        buf->writestring(ident->toChars());
    else
        buf->printf("%u", level);
    buf->writestring(";");
    buf->writenl();
}

const char *DebugSymbol::kind()
{
    return "debug";
}

/* ================================================== */

/* VersionSymbol's happen for statements like:
 *      version = identifier;
 *      version = integer;
 */

VersionSymbol::VersionSymbol(Loc loc, Identifier *ident)
    : Dsymbol(ident)
{
    this->loc = loc;
}

VersionSymbol::VersionSymbol(Loc loc, unsigned level)
    : Dsymbol()
{
    this->level = level;
    this->loc = loc;
}

Dsymbol *VersionSymbol::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    VersionSymbol *ds = new VersionSymbol(loc, ident);
    ds->level = level;
    return ds;
}

int VersionSymbol::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    //printf("VersionSymbol::addMember('%s') %s\n", sd->toChars(), toChars());
    Module *m;

    // Do not add the member to the symbol table,
    // just make sure subsequent debug declarations work.
    m = sd->isModule();
    if (ident)
    {
        VersionCondition::checkPredefined(loc, ident->toChars());
        if (!m)
            error("declaration must be at module level");
        else
        {
            if (findCondition(m->versionidsNot, ident))
                error("defined after use");
            if (!m->versionids)
                m->versionids = new Strings();
            m->versionids->push(ident->toChars());
        }
    }
    else
    {
        if (!m)
            error("level declaration must be at module level");
        else
            m->versionlevel = level;
    }
    return 0;
}

void VersionSymbol::semantic(Scope *sc)
{
}

void VersionSymbol::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("version = ");
    if (ident)
        buf->writestring(ident->toChars());
    else
        buf->printf("%u", level);
    buf->writestring(";");
    buf->writenl();
}

const char *VersionSymbol::kind()
{
    return "version";
}


