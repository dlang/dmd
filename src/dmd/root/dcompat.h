
/* Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/root/dcompat.h
 */

#pragma once

#include <stddef.h>
#include <string.h>

/// Represents a D [ ] array
template<typename T>
struct DArray
{
    size_t length;
    T *ptr;

    DArray() : length(0), ptr(NULL) { }

    DArray(size_t length_in, T *ptr_in)
        : length(length_in), ptr(ptr_in) { }
};

struct DString : public DArray<const char>
{
    DString() : DArray() { }

    DString(const char *ptr)
        : DArray(strlen(ptr), ptr) { }

    DString(size_t length, const char *ptr)
        : DArray(length, ptr) { }
};
