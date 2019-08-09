
/* Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/object.h
 */

#pragma once

#define POSIX (__linux__ || __GLIBC__ || __gnu_hurd__ || __APPLE__ || __FreeBSD__ || __DragonFly__ || __OpenBSD__ || __sun)

#include "dcompat.h"
#include <stddef.h>

typedef size_t hash_t;

struct OutBuffer;

enum DYNCAST
{
    DYNCAST_OBJECT,
    DYNCAST_EXPRESSION,
    DYNCAST_DSYMBOL,
    DYNCAST_TYPE,
    DYNCAST_IDENTIFIER,
    DYNCAST_TUPLE,
    DYNCAST_PARAMETER,
    DYNCAST_STATEMENT,
    DYNCAST_TEMPLATEPARAMETER
};

/*
 * Root of our class library.
 */
class RootObject
{
public:
    RootObject() { }

    virtual bool equals(RootObject *o);

    /**
     * Pretty-print an Object. Useful for debugging the old-fashioned way.
     */
    virtual const char *toChars();
    /// This function is `extern(D)` and should not be called from C++,
    /// as the ABI does not match on some platforms
    virtual DString toString();

    /**
     * Used as a replacement for dynamic_cast. Returns a unique number
     * defined by the library user. For Object, the return value is 0.
     */
    virtual DYNCAST dyncast() const;
};
