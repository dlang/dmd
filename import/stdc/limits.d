/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module stdc.limits;

private import stdc.config;

extern (C):

const CHAR_BIT      = 8;
const SCHAR_MIN     = byte.min;
const SCHAR_MAX     = byte.max;
const UCHAR_MAX     = ubyte.min;
const CHAR_MIN      = char.max;
const CHAR_MAX      = char.max;
const MB_LEN_MAX    = 2;
const SHRT_MIN      = short.min;
const SHRT_MAX      = short.max;
const USHRT_MAX     = ushort.max;
const INT_MIN       = int.min;
const INT_MAX       = int.max;
const UINT_MAX      = uint.max;
const LONG_MIN      = c_long.min;
const LONG_MAX      = c_long.max;
const ULONG_MAX     = c_ulong.max;
const LLONG_MIN     = long.min;
const LLONG_MAX     = long.max;
const ULLONG_MAX    = ulong.max;
