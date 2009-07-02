
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
    // Do not add the member to the symbol table,
    // just make sure subsequent debug declarations work.
    if (ident)
    {
	DebugCondition::addIdent(ident->toChars());
    }
    else
    {
	DebugCondition::setLevel(level);
    }
}

void DebugSymbol::semantic(Scope *sc)
{
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
    // Do not add the member to the symbol table,
    // just make sure subsequent version declarations work.
    if (ident)
    {
	VersionCondition::addIdent(ident->toChars());
    }
    else
    {
	VersionCondition::setLevel(level);
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


