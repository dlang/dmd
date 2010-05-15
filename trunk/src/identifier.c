
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
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

const char *Identifier::toHChars2()
{
    const char *p = NULL;

    if (this == Id::ctor) p = "this";
    else if (this == Id::dtor) p = "~this";
    else if (this == Id::classInvariant) p = "invariant";
    else if (this == Id::unitTest) p = "unittest";
    else if (this == Id::dollar) p = "$";
    else if (this == Id::withSym) p = "with";
    else if (this == Id::result) p = "result";
    else if (this == Id::returnLabel) p = "return";
    else
    {   p = toChars();
        if (*p == '_')
        {
            if (memcmp(p, "_staticCtor", 11) == 0)
                p = "static this";
            else if (memcmp(p, "_staticDtor", 11) == 0)
                p = "static ~this";
        }
    }

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

// BUG: these are redundant with Lexer::uniqueId()

Identifier *Identifier::generateId(const char *prefix)
{
    static size_t i;

    return generateId(prefix, ++i);
}

Identifier *Identifier::generateId(const char *prefix, size_t i)
{   OutBuffer buf;

    buf.writestring(prefix);
    buf.printf("%zu", i);

    char *id = buf.toChars();
    buf.data = NULL;
    return Lexer::idPool(id);
}
