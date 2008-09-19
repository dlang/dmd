/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module stdc.locale;

extern (C):

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

const LC_CTYPE          = 0;
const LC_NUMERIC        = 1;
const LC_TIME           = 2;
const LC_COLLATE        = 3;
const LC_MONETARY       = 4;
const LC_ALL            = 6;
const LC_PAPER          = 7;
const LC_NAME           = 8;
const LC_ADDRESS        = 9;
const LC_TELEPHONE      = 10;
const LC_MEASUREMENT    = 11;
const LC_IDENTIFICATION = 12;

char*  setlocale(int category, in char* locale);
lconv* localeconv();
