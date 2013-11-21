
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_IDENTIFIER_H
#define DMD_IDENTIFIER_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"

class Identifier : public RootObject
{
public:
    int value;
    const char *string;
    size_t len;

    Identifier(const char *string, int value);
    bool equals(RootObject *o);
    int compare(RootObject *o);
    void print();
    char *toChars();
    const char *toHChars2();
    int dyncast();

    static Identifier *generateId(const char *prefix);
    static Identifier *generateId(const char *prefix, size_t i);
};

#endif /* DMD_IDENTIFIER_H */
