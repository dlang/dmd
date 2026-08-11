
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * https://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * https://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/common/int128.h
 */

#pragma once

#include <cstdint>

// Mirrors dmd.common.int128.Cent
struct alignas(16) Cent
{
    uint64_t lo;    // low 64 bits
    uint64_t hi;    // high 64 bits
};
