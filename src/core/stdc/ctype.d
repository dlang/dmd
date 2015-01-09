/**
 * D header file for C99.
 *
 * This contains bindings to selected types and functions from the standard C
 * header $(LINK2 http://pubs.opengroup.org/onlinepubs/009695399/basedefs/ctype.h.html, <ctype.h>). Note
 * that this is not automatically generated, and may omit some types/functions
 * from the original C header.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/stdc/_ctype.d)
 * Standards: ISO/IEC 9899:1999 (E)
 */

module core.stdc.ctype;

extern (C):
@trusted: // All of these operate on integers only.
nothrow:
@nogc:

    ///
pure int isalnum(int c);
///
pure int isalpha(int c);
///
pure int isblank(int c);
///
pure int iscntrl(int c);
///
pure int isdigit(int c);
///
pure int isgraph(int c);
///
pure int islower(int c);
///
pure int isprint(int c);
///
pure int ispunct(int c);
///
pure int isspace(int c);
///
pure int isupper(int c);
///
pure int isxdigit(int c);
///
pure int tolower(int c);
///
pure int toupper(int c);
