
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/compiler/src/dmd/argtypes.h
 */

#pragma once

class Type;
class TypeTuple;

namespace dmd
{
    // in argtypes_x86.d
    TypeTuple *toArgTypes_x86(Type *t);
    // in argtypes_sysv_x64.d
    TypeTuple *toArgTypes_sysv_x64(Type *t);
    // in argtypes_aarch64.d
    TypeTuple *toArgTypes_aarch64(Type *t);
    bool isHFVA(Type *t, int maxNumElements = 4, Type **rewriteType = nullptr);
}
