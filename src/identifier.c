
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/identifier.c
 */

#include <stdio.h>
#include <string.h>

#include "root.h"
#include "identifier.h"
#include "mars.h"
#include "id.h"
#include "tokens.h"

Identifier::Identifier(const char *string, int value)
{
    //printf("Identifier('%s', %d)\n", string, value);
    this->string = string;
    this->value = value;
    this->len = strlen(string);
}

Identifier *Identifier::create(const char *string, int value)
{
    return new Identifier(string, value);
}

bool Identifier::equals(RootObject *o)
{
    return this == o || strncmp(string,o->toChars(),len+1) == 0;
}

int Identifier::compare(RootObject *o)
{
    return strncmp(string, o->toChars(), len + 1);
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
    else if (this == Id::unitTest) p = "unittest";
    else if (this == Id::dollar) p = "$";
    else if (this == Id::withSym) p = "with";
    else if (this == Id::result) p = "result";
    else if (this == Id::returnLabel) p = "return";
    else
    {   p = toChars();
        if (*p == '_')
        {
            if (strncmp(p, "_staticCtor", 11) == 0)
                p = "static this";
            else if (strncmp(p, "_staticDtor", 11) == 0)
                p = "static ~this";
            else if (strncmp(p, "__invariant", 11) == 0)
                p = "invariant";
        }
    }

    return p;
}

void Identifier::print()
{
    fprintf(stderr, "%s",string);
}

int Identifier::dyncast()
{
    return DYNCAST_IDENTIFIER;
}

StringTable Identifier::stringtable;

Identifier *Identifier::generateId(const char *prefix)
{
    static size_t i;

    return generateId(prefix, ++i);
}

Identifier *Identifier::generateId(const char *prefix, size_t i)
{   OutBuffer buf;

    buf.writestring(prefix);
    buf.printf("%llu", (ulonglong)i);

    char *id = buf.peekString();
    return idPool(id);
}

/********************************************
 * Create an identifier in the string table.
 */

Identifier *Identifier::idPool(const char *s)
{
    return idPool(s, strlen(s));
}

Identifier *Identifier::idPool(const char *s, size_t len)
{
    StringValue *sv = stringtable.update(s, len);
    Identifier *id = (Identifier *) sv->ptrvalue;
    if (!id)
    {
        id = new Identifier(sv->toDchars(), TOKidentifier);
        sv->ptrvalue = (char *)id;
    }
    return id;
}

Identifier *Identifier::lookup(const char *s, size_t len)
{
    StringValue *sv = stringtable.lookup(s, len);
    if (!sv)
        return NULL;
    return (Identifier *)sv->ptrvalue;
}

void Identifier::initTable()
{
    stringtable._init(28000);
}
