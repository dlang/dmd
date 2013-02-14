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
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.stdc.ctype;

extern (C):
@trusted: // All of these operate on integers only.
nothrow:

pure int isalnum(int c);
pure int isalpha(int c);
pure int isblank(int c);
pure int iscntrl(int c);
pure int isdigit(int c);
pure int isgraph(int c);
pure int islower(int c);
pure int isprint(int c);
pure int ispunct(int c);
pure int isspace(int c);
pure int isupper(int c);
pure int isxdigit(int c);
pure int tolower(int c);
pure int toupper(int c);
