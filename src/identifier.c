
// Copyright (c) 1999-2002 by Digital Mars
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

Identifier::Identifier(const char *string, int value)
{
    //printf("Identifier('%s', %d)\n", string, value);
    this->string = string;
    this->value = value;
}

unsigned Identifier::hashCode()
{
    return String::calcHash(string);
}

int Identifier::equals(Object *o)
{
    return this == o || strcmp(string,o->toChars()) == 0;
}

int Identifier::compare(Object *o)
{
    return strcmp(string,o->toChars());
}

char *Identifier::toChars()
{
    return (char *)string;
}

void Identifier::print()
{
    printf("%s",string);
}

int Identifier::dyncast()
{
    return DYNCAST_IDENTIFIER;
}
