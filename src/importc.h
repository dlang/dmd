/* This .h file is to be #include'd by ImportC files first in order provide
 * adjustments to the source to account for various C compiler extensions
 * not supported by ImportC.
 *
 * Copyright: Copyright D Language Foundation 2022
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Walter Bright
 * Source: $(DRUNTIMESRC importc.h)
 */

/**********************
 * For special casing ImportC code.
 */
#define __IMPORTC__ 1

/********************
 * Some compilers define `__restrict` instead of `restrict` as C++ compilers don't
 * recognize `restrict` as a keyword.
 * ImportC assigns no semantics to `restrict`, so just ignore the keyword.
 */
#define __restrict

/********************
 * This is a Microsoft C function calling convention not supported by ImportC,
 * so ignore it.
 */
#define __fastcall

/*********************
 * Obsolete detritus
 */
#define __cdecl
#define __ss
#define __cs
#define __far
#define __near
#define __handle
#define __inline        // ImportC does its own notion of inlining
#define __pascal

/****************************
 * __extension__ is a GNU C extension. It suppresses warnings
 * when placed before an expression.
 */
#define __extension__  // ignore it, as ImportC doesn't do warnings

/****************************
 * Define it to do what other C compilers do.
 */
#define __builtin_offset(t,i) ((size_t)((char *)&((t *)0)->i - (char *)0))
