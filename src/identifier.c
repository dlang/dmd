
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>

#include "root.h"
#include "identifier.h"
#include "mars.h"
#include "lexer.h"
#include "id.h"

Identifier::Identifier(const char *string, int value)
{
    //printf("Identifier('%s', %d)\n", string, value);
    this->string = string;
    this->value = value;
    this->len = strlen(string);
}

hash_t Identifier::hashCode()
{
    return String::calcHash(string);
}

int Identifier::equals(Object *o)
{
    return this == o || memcmp(string,o->toChars(),len+1) == 0;
}

int Identifier::compare(Object *o)
{
    return memcmp(string, o->toChars(), len + 1);
}

char *Identifier::toChars()
{
    return (char *)string;
}

char *Identifier::toHChars2()
{
    char *p = NULL;

    if (this == Id::ctor) p = "this";
    else if (this == Id::dtor) p = "~this";
    else if (this == Id::classInvariant) p = "invariant";
    else if (this == Id::unitTest) p = "unittest";
    else if (this == Id::staticCtor) p = "static this";
    else if (this == Id::staticDtor) p = "static ~this";
    else if (this == Id::dollar) p = "$";
    else if (this == Id::withSym) p = "with";
    else if (this == Id::result) p = "result";
    else if (this == Id::returnLabel) p = "return";
    else
	p = toChars();

    return p;
}

void Identifier::print()
{
    fprintf(stdmsg, "%s",string);
}

int Identifier::dyncast()
{
    return DYNCAST_IDENTIFIER;
}

Identifier *Identifier::generateId(char *prefix)
{   OutBuffer buf;
    char *id;
    static unsigned i;

    buf.writestring(prefix);
    buf.printf("%u", ++i);

    id = buf.toChars();
    buf.data = NULL;
    return new Identifier(id, TOKidentifier);
}
