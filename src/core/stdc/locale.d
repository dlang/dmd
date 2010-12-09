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
module core.stdc.locale;

extern (C):

nothrow:

struct lconv
{
    char* decimal_point;
    char* thousands_sep;
    char* grouping;
    char* int_curr_symbol;
    char* currency_symbol;
    char* mon_decimal_point;
    char* mon_thousands_sep;
    char* mon_grouping;
    char* positive_sign;
    char* negative_sign;
    byte  int_frac_digits;
    byte  frac_digits;
    byte  p_cs_precedes;
    byte  p_sep_by_space;
    byte  n_cs_precedes;
    byte  n_sep_by_space;
    byte  p_sign_posn;
    byte  n_sign_posn;
    byte  int_p_cs_precedes;
    byte  int_p_sep_by_space;
    byte  int_n_cs_precedes;
    byte  int_n_sep_by_space;
    byte  int_p_sign_posn;
    byte  int_n_sign_posn;
}

enum LC_CTYPE          = 0;
enum LC_NUMERIC        = 1;
enum LC_TIME           = 2;
enum LC_COLLATE        = 3;
enum LC_MONETARY       = 4;
enum LC_ALL            = 6;
enum LC_PAPER          = 7;  // non-standard
enum LC_NAME           = 8;  // non-standard
enum LC_ADDRESS        = 9;  // non-standard
enum LC_TELEPHONE      = 10; // non-standard
enum LC_MEASUREMENT    = 11; // non-standard
enum LC_IDENTIFICATION = 12; // non-standard

char*  setlocale(int category, in char* locale);
lconv* localeconv();
