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
module core.stdc.wctype;

public  import core.stdc.wchar_; // for wint_t, WEOF

extern (C):
nothrow:

alias wchar_t wctrans_t;
alias wchar_t wctype_t;

int iswalnum(wint_t wc);
int iswalpha(wint_t wc);
int iswblank(wint_t wc);
int iswcntrl(wint_t wc);
int iswdigit(wint_t wc);
int iswgraph(wint_t wc);
int iswlower(wint_t wc);
int iswprint(wint_t wc);
int iswpunct(wint_t wc);
int iswspace(wint_t wc);
int iswupper(wint_t wc);
int iswxdigit(wint_t wc);

int       iswctype(wint_t wc, wctype_t desc);
wctype_t  wctype(in char* property);
wint_t    towlower(wint_t wc);
wint_t    towupper(wint_t wc);
wint_t    towctrans(wint_t wc, wctrans_t desc);
wctrans_t wctrans(in char* property);
