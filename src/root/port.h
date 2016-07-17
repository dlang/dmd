
/* Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/dlang/dmd/blob/master/src/root/port.h
 */

#ifndef PORT_H
#define PORT_H

// Portable wrapper around compiler/system specific things.
// The idea is to minimize #ifdef's in the app code.

#include <stdlib.h> // for alloca
#include <stdint.h>

#if _MSC_VER
#include <alloca.h>
typedef __int64 longlong;
typedef unsigned __int64 ulonglong;
#else
typedef long long longlong;
typedef unsigned long long ulonglong;
#endif

typedef unsigned char utf8_t;

struct Port
{
    static int memicmp(const char *s1, const char *s2, int n);
    static char *strupr(char *s);

    static bool isFloat32LiteralOutOfRange(const char *s);
    static bool isFloat64LiteralOutOfRange(const char *s);

    static void writelongLE(unsigned value, void *buffer);
    static unsigned readlongLE(void *buffer);
    static void writelongBE(unsigned value, void *buffer);
    static unsigned readlongBE(void *buffer);
    static unsigned readwordLE(void *buffer);
    static unsigned readwordBE(void *buffer);
    static void valcpy(void *dst, uint64_t val, size_t size);
};

#endif
