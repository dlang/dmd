
// Copyright (c) 1999-2003 by Digital Mars
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

	//printf("Declaration::mangle(this = %p, '%s', parent = '%s')\n", this, toChars(), parent ? parent->toChars() : "null");
	if (!parent || parent->isModule())	// if at global scope
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
	    //printf("s = %p, '%s', parent = %p\n", s, s->toChars(), s->parent);
#if 1
	    if (s->ident)
	    {	id = s->ident->toChars();
		int len = strlen(id);
		char tmp[sizeof(len) * 3 + 1];
		buf.prependstring(id);
		sprintf(tmp, "%d", len);
		buf.prependstring(tmp);
	    }
	    else
		buf.prependstring("0");
#else
	    if (s->ident)
	    {	buf.prependstring("_");
		buf.prependstring(s->ident->toChars());
	    }
	    else
		buf.prependstring("_");
#endif
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
    //printf("StructDeclaration::mangle() '%s'\n", toChars());
    return Dsymbol::mangle();
}


char *TypedefDeclaration::mangle()
{
    //printf("TypedefDeclaration::mangle() '%s'\n", toChars());
    return Dsymbol::mangle();
}


char *ClassDeclaration::mangle()
{
    Dsymbol *parentsave = parent;

    /* These are reserved to the compiler, so keep simple
     * names for them.
     */
    if (ident == Id::TypeInfo   ||
	ident == Id::Exception  ||
	ident == Id::Object     ||
	ident == Id::ClassInfo  ||
	ident == Id::ModuleInfo ||
	memcmp(ident->toChars(), "TypeInfo_", 9) == 0
       )
	parent = NULL;

    char *id = Dsymbol::mangle();
    parent = parentsave;
    return id;
}


char *TemplateInstance::mangle()
{
    return Dsymbol::mangle();
}



char *Dsymbol::mangle()
{
    OutBuffer buf;
    char *id;

    //printf("Dsymbol::mangle() '%s'\n", toChars());
    id = ident ? ident->toChars() : toChars();
    if (parent)
    {
	//printf("  parent = '%s', kind = '%s'\n", parent->mangle(), parent->kind());
	buf.writestring(parent->mangle());
    }
    buf.printf("%d%s", strlen(id), id);
    //buf.writestring("_");
    //buf.writestring(id);
    id = buf.toChars();
    buf.data = NULL;
    return id;
}


