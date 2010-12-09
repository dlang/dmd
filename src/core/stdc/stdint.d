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
module core.stdc.stdint;

private import core.stdc.stddef; // for ptrdiff_t, size_t, wchar_t
private import core.stdc.signal; // for sig_atomic_t
private import core.stdc.wchar_; // for wint_t

private
{
    template typify(T)
    {
        T typify( T val ) { return val; }
    }
}

extern (C):

alias byte      int8_t;
alias short     int16_t;
alias int       int32_t;
alias long      int64_t;
//alias cent      int128_t;

alias ubyte     uint8_t;
alias ushort    uint16_t;
alias uint      uint32_t;
alias ulong     uint64_t;
//alias ucent     uint128_t;

alias byte      int_least8_t;
alias short     int_least16_t;
alias int       int_least32_t;
alias long      int_least64_t;

alias ubyte     uint_least8_t;
alias ushort    uint_least16_t;
alias uint      uint_least32_t;
alias ulong     uint_least64_t;

alias byte      int_fast8_t;
alias int       int_fast16_t;
alias int       int_fast32_t;
alias long      int_fast64_t;

alias ubyte     uint_fast8_t;
alias uint      uint_fast16_t;
alias uint      uint_fast32_t;
alias ulong     uint_fast64_t;

version( X86_64 )
{
    alias long  intptr_t;
    alias ulong uintptr_t;
}
else
{
    alias int   intptr_t;
    alias uint  uintptr_t;
}

alias long      intmax_t;
alias ulong     uintmax_t;

enum int8_t   INT8_MIN  = int8_t.min;
enum int8_t   INT8_MAX  = int8_t.max;
enum int16_t  INT16_MIN = int16_t.min;
enum int16_t  INT16_MAX = int16_t.max;
enum int32_t  INT32_MIN = int32_t.min;
enum int32_t  INT32_MAX = int32_t.max;
enum int64_t  INT64_MIN = int64_t.min;
enum int64_t  INT64_MAX = int64_t.max;

enum uint8_t  UINT8_MAX  = uint8_t.max;
enum uint16_t UINT16_MAX = uint16_t.max;
enum uint32_t UINT32_MAX = uint32_t.max;
enum uint64_t UINT64_MAX = uint64_t.max;

enum int_least8_t    INT_LEAST8_MIN   = int_least8_t.min;
enum int_least8_t    INT_LEAST8_MAX   = int_least8_t.max;
enum int_least16_t   INT_LEAST16_MIN  = int_least16_t.min;
enum int_least16_t   INT_LEAST16_MAX  = int_least16_t.max;
enum int_least32_t   INT_LEAST32_MIN  = int_least32_t.min;
enum int_least32_t   INT_LEAST32_MAX  = int_least32_t.max;
enum int_least64_t   INT_LEAST64_MIN  = int_least64_t.min;
enum int_least64_t   INT_LEAST64_MAX  = int_least64_t.max;

enum uint_least8_t   UINT_LEAST8_MAX  = uint_least8_t.max;
enum uint_least16_t  UINT_LEAST16_MAX = uint_least16_t.max;
enum uint_least32_t  UINT_LEAST32_MAX = uint_least32_t.max;
enum uint_least64_t  UINT_LEAST64_MAX = uint_least64_t.max;

enum int_fast8_t   INT_FAST8_MIN   = int_fast8_t.min;
enum int_fast8_t   INT_FAST8_MAX   = int_fast8_t.max;
enum int_fast16_t  INT_FAST16_MIN  = int_fast16_t.min;
enum int_fast16_t  INT_FAST16_MAX  = int_fast16_t.max;
enum int_fast32_t  INT_FAST32_MIN  = int_fast32_t.min;
enum int_fast32_t  INT_FAST32_MAX  = int_fast32_t.max;
enum int_fast64_t  INT_FAST64_MIN  = int_fast64_t.min;
enum int_fast64_t  INT_FAST64_MAX  = int_fast64_t.max;

enum uint_fast8_t  UINT_FAST8_MAX  = uint_fast8_t.max;
enum uint_fast16_t UINT_FAST16_MAX = uint_fast16_t.max;
enum uint_fast32_t UINT_FAST32_MAX = uint_fast32_t.max;
enum uint_fast64_t UINT_FAST64_MAX = uint_fast64_t.max;

enum intptr_t  INTPTR_MIN  = intptr_t.min;
enum intptr_t  INTPTR_MAX  = intptr_t.max;

enum uintptr_t UINTPTR_MIN = uintptr_t.min;
enum uintptr_t UINTPTR_MAX = uintptr_t.max;

enum intmax_t  INTMAX_MIN  = intmax_t.min;
enum intmax_t  INTMAX_MAX  = intmax_t.max;

enum uintmax_t UINTMAX_MAX = uintmax_t.max;

enum ptrdiff_t PTRDIFF_MIN = ptrdiff_t.min;
enum ptrdiff_t PTRDIFF_MAX = ptrdiff_t.max;

enum sig_atomic_t SIG_ATOMIC_MIN = sig_atomic_t.min;
enum sig_atomic_t SIG_ATOMIC_MAX = sig_atomic_t.max;

enum size_t  SIZE_MAX  = size_t.max;

enum wchar_t WCHAR_MIN = wchar_t.min;
enum wchar_t WCHAR_MAX = wchar_t.max;

enum wint_t  WINT_MIN  = wint_t.min;
enum wint_t  WINT_MAX  = wint_t.max;

alias typify!(int8_t)  INT8_C;
alias typify!(int16_t) INT16_C;
alias typify!(int32_t) INT32_C;
alias typify!(int64_t) INT64_C;

alias typify!(uint8_t)  UINT8_C;
alias typify!(uint16_t) UINT16_C;
alias typify!(uint32_t) UINT32_C;
alias typify!(uint64_t) UINT64_C;

alias typify!(intmax_t)  INTMAX_C;
alias typify!(uintmax_t) UINTMAX_C;
