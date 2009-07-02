
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "root.h"

#include "declaration.h"
#include "mtype.h"
#include "attrib.h"
#include "template.h"

char *Declaration::mangle()
#if __DMC__
    __out(result)
    {
	int len = strlen(result);

	assert(len > 0);
	//printf("mangle: '%s' => '%s'\n", toChars(), result);
	for (int i = 0; i < len; i++)
	{
	    assert(result[i] == '_' || isalnum(result[i]));
	}
    }
    __body
#endif
    {
	OutBuffer buf;
	char *id;
	Dsymbol *s;

	//printf("Declaration::mangle(parent = %p)\n", parent);
	if (!parent || dynamic_cast<Module *>(parent))	// if at global scope
	{
	    // If it's not a D declaration, no mangling
	    switch (linkage)
	    {
		case LINKd:
		    break;

		case LINKc:
		case LINKwindows:
		case LINKpascal:
		case LINKcpp:
		    return ident->toChars();

		default:
		    printf("'%s', linkage = %d\n", toChars(), linkage);
		    assert(0);
	    }
	}

	s = this;
	do
	{
	    buf.prependstring("_");
	    if (s->ident)
		buf.prependstring(s->ident->toChars());
	    s = s->parent;
	} while (s);

	buf.prependstring("_D");
	buf.writestring(type->deco);

	id = buf.toChars();
	buf.data = NULL;
	return id;
    }

char *FuncDeclaration::mangle()
#if __DMC__
    __out(result)
    {
	assert(strlen(result) > 0);
    }
    __body
#endif
    {
	if (isMain())
	    return "_Dmain";

	return Declaration::mangle();
    }

char *StructDeclaration::mangle()
{
    OutBuffer buf;
    char *id;
    Dsymbol *s;

    s = this;
    while (1)
    {
	buf.prependstring(s->ident ? s->ident->toChars() : s->toChars());
	s = s->parent;
	if (!s)
	    break;
	buf.prependstring("_");
    }

    id = buf.toChars();
    buf.data = NULL;
    return id;
}


char *ClassDeclaration::mangle()
{
    OutBuffer buf;
    char *id;
    Dsymbol *s;

    s = this;
    while (1)
    {
	buf.prependstring(s->ident ? s->ident->toChars() : s->toChars());
	s = s->parent;
	if (!s || !dynamic_cast<TemplateInstance *>(s))
	    break;
	buf.prependstring("_");
    }

    id = buf.toChars();
    buf.data = NULL;
    return id;
}



