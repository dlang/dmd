
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "declaration.h"
#include "identifier.h"
#include "expression.h"
#include "debcond.h"

int findCondition(Array *ids, Identifier *ident)
{
    if (ids)
    {
	for (int i = 0; i < ids->dim; i++)
	{
	    char *id = (char *)ids->data[i];

	    if (strcmp(id, ident->toChars()) == 0)
		return TRUE;
	}
    }

    return FALSE;
}

/* ============================================================ */

Condition::Condition(Module *mod, unsigned level, Identifier *ident)
{
    this->mod = mod;
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

void DebugCondition::setGlobalLevel(unsigned level)
{
    global.params.debuglevel = level;
}

void DebugCondition::addGlobalIdent(char *ident)
{
    if (!global.params.debugids)
	global.params.debugids = new Array();
    global.params.debugids->push(ident);
}


DebugCondition::DebugCondition(Module *mod, unsigned level, Identifier *ident)
    : Condition(mod, level, ident)
{
}

int DebugCondition::include()
{
    //printf("DebugCondition::include() level = %d, debuglevel = %d\n", level, global.params.debuglevel);
    if (ident)
    {
	if (findCondition(mod->debugids, ident))
	    return TRUE;

	if (findCondition(global.params.debugids, ident))
	    return TRUE;
    }
    else if (level <= global.params.debuglevel || level <= mod->debuglevel)
	return TRUE;
    return FALSE;
}

/* ============================================================ */

void VersionCondition::setGlobalLevel(unsigned level)
{
    global.params.versionlevel = level;
}

void VersionCondition::addGlobalIdent(char *ident)
{
    if (!global.params.versionids)
	global.params.versionids = new Array();
    global.params.versionids->push(ident);
}


VersionCondition::VersionCondition(Module *mod, unsigned level, Identifier *ident)
    : Condition(mod, level, ident)
{
}

int VersionCondition::include()
{
    //printf("VersionCondition::include() level = %d, versionlevel = %d\n", level, global.params.versionlevel);
    if (ident)
    {
	if (findCondition(mod->versionids, ident))
	    return TRUE;

	if (findCondition(global.params.versionids, ident))
	    return TRUE;
    }
    else if (level <= global.params.versionlevel || level <= mod->versionlevel)
	return TRUE;
    return FALSE;
}

