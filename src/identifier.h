
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/identifier.h
 */

#ifndef DMD_IDENTIFIER_H
#define DMD_IDENTIFIER_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "stringtable.h"

class Identifier : public RootObject
{
public:
    int value;
    const char *string;
    size_t len;

    Identifier(const char *string, int value);
    static Identifier* create(const char *string, int value);
    bool equals(RootObject *o);
    int compare(RootObject *o);
    void print();
    char *toChars();
    const char *toHChars2();
    int dyncast();

    static StringTable stringtable;
    static Identifier *generateId(const char *prefix);
    static Identifier *generateId(const char *prefix, size_t i);
    static Identifier *idPool(const char *s);
    static Identifier *idPool(const char *s, size_t len);
    static Identifier *lookup(const char *s, size_t len);
    static void initTable();
};

#endif /* DMD_IDENTIFIER_H */
