
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "declaration.h"
#include "identifier.h"
#include "expression.h"
#include "debcond.h"

Condition::Condition(unsigned level, Identifier *ident)
{
    this->level = level;
    this->ident = ident;
}

int Condition::include()
{
    assert(0);
    return FALSE;
}

int Condition::isBool(int result)
{
    return (result == include());
}

Expression *Condition::toExpr()
{
    assert(0);		// BUG: not implemented
    return NULL;
}

void Condition::toCBuffer(OutBuffer *buf)
{
    if (ident)
	buf->printf("%s", ident->toChars());
    else
	buf->printf("%u", level);
}

/* ============================================================ */

void DebugCondition::setLevel(unsigned level)
{
    global.params.debuglevel = level;
}

void DebugCondition::addIdent(char *ident)
{
    if (!global.params.debugids)
	global.params.debugids = new Array();
    global.params.debugids->push(ident);
}


DebugCondition::DebugCondition(unsigned level, Identifier *ident)
    : Condition(level, ident)
{
}

int DebugCondition::include()
{
    //printf("DebugCondition::include() level = %d, debuglevel = %d\n", level, global.params.debuglevel);
    if (ident)
    {
	if (global.params.debugids)
	{
	    for (int i = 0; i < global.params.debugids->dim; i++)
	    {
		char *id = (char *)global.params.debugids->data[i];

		if (strcmp(id, ident->toChars()) == 0)
		    return TRUE;
	    }
	}
    }
    else if (level <= global.params.debuglevel)
	return TRUE;
    return FALSE;
}

/* ============================================================ */

void VersionCondition::setLevel(unsigned level)
{
    global.params.versionlevel = level;
}

void VersionCondition::addIdent(char *ident)
{
    if (!global.params.versionids)
	global.params.versionids = new Array();
    global.params.versionids->push(ident);
}


VersionCondition::VersionCondition(unsigned level, Identifier *ident)
    : Condition(level, ident)
{
    this->level = level;
    this->ident = ident;
}

int VersionCondition::include()
{
    //printf("VersionCondition::include() level = %d, versionlevel = %d\n", level, global.params.versionlevel);
    if (ident)
    {
	if (global.params.versionids)
	{
	    for (int i = 0; i < global.params.versionids->dim; i++)
	    {
		char *id = (char *)global.params.versionids->data[i];

		if (strcmp(id, ident->toChars()) == 0)
		    return TRUE;
	    }
	}
    }
    else if (level <= global.params.versionlevel)
	return TRUE;
    return FALSE;
}

