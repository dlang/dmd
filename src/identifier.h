
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

#include "root.h"

struct Identifier : Object
{
    int value;
    const char *string;

    Identifier(const char *string, int value);
    int equals(Object *o);
    unsigned hashCode();
    int compare(Object *o);
    void print();
    char *toChars();
};
