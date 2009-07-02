
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>

#include "root.h"

#include "identifier.h"
#include "dsymbol.h"
#include "debcond.h"
#include "version.h"

/* ================================================== */

DebugSymbol::DebugSymbol(Identifier *ident)
    : Dsymbol(ident)
{
}

DebugSymbol::DebugSymbol(unsigned level)
    : Dsymbol()
{
    this->level = level;
}

void DebugSymbol::addMember(ScopeDsymbol *sd)
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
	    if (!m->debugids)
		m->debugids = new Array();
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
}

void DebugSymbol::semantic(Scope *sc)
{
    //printf("DebugSymbol::semantic() %s\n", toChars());
}

void DebugSymbol::toCBuffer(OutBuffer *buf)
{
    buf->writestring("debug = ");
    if (ident)
	buf->writestring(ident->toChars());
    else
	buf->printf("%u", level);
    buf->writestring(";");
    buf->writenl();
}

char *DebugSymbol::kind()
{
    return "debug";
}

/* ================================================== */

VersionSymbol::VersionSymbol(Identifier *ident)
    : Dsymbol(ident)
{
}

VersionSymbol::VersionSymbol(unsigned level)
    : Dsymbol()
{
    this->level = level;
}

void VersionSymbol::addMember(ScopeDsymbol *sd)
{
    //printf("VersionSymbol::addMember('%s') %s\n", sd->toChars(), toChars());
    Module *m;

    // Do not add the member to the symbol table,
    // just make sure subsequent debug declarations work.
    m = sd->isModule();
    if (ident)
    {
	VersionCondition::checkPredefined(ident->toChars());
	if (!m)
	    error("declaration must be at module level");
	else
	{
	    if (!m->versionids)
		m->versionids = new Array();
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
}

void VersionSymbol::semantic(Scope *sc)
{
}

void VersionSymbol::toCBuffer(OutBuffer *buf)
{
    buf->writestring("version = ");
    if (ident)
	buf->writestring(ident->toChars());
    else
	buf->printf("%u", level);
    buf->writestring(";");
    buf->writenl();
}

char *VersionSymbol::kind()
{
    return "version";
}


