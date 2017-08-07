
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/identifier.h
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
private:
    int value;
    const char *string;
    size_t len;

public:
    static Identifier* create(const char *string);
    bool equals(RootObject *o);
    int compare(RootObject *o);
    void print();
    const char *toChars();
    int getValue() const;
    const char *toHChars2();
    int dyncast() const;

    static StringTable stringtable;
    static Identifier *generateId(const char *prefix);
    static Identifier *generateId(const char *prefix, size_t i);
    static Identifier *idPool(const char *s, size_t len);
    static bool isValidIdentifier(const char *p);
    static Identifier *lookup(const char *s, size_t len);
    static void initTable();
};

#endif /* DMD_IDENTIFIER_H */
