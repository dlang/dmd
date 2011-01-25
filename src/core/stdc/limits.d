/**
 * D header file for C99.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.stdc.limits;

private import core.stdc.config;

extern (C):

enum CHAR_BIT       = 8;
enum SCHAR_MIN      = byte.min;
enum SCHAR_MAX      = byte.max;
enum UCHAR_MAX      = ubyte.max;
enum CHAR_MIN       = char.min;
enum CHAR_MAX       = char.max;
enum MB_LEN_MAX     = 2;
enum SHRT_MIN       = short.min;
enum SHRT_MAX       = short.max;
enum USHRT_MAX      = ushort.max;
enum INT_MIN        = int.min;
enum INT_MAX        = int.max;
enum UINT_MAX       = uint.max;
enum LONG_MIN       = c_long.min;
enum LONG_MAX       = c_long.max;
enum ULONG_MAX      = c_ulong.max;
enum LLONG_MIN      = long.min;
enum LLONG_MAX      = long.max;
enum ULLONG_MAX     = ulong.max;
