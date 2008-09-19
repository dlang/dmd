/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module stdc.stddef;

extern (C):

//alias typeof(int.sizeof)                    size_t;
//alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;

version( Windows )
{
    alias wchar wint_t;
    alias wchar wchar_t;
    alias wchar wctype_t;
    alias wchar wctrans_t;

    const wchar WEOF = 0xFFFF;
}
else
{
    alias dchar wint_t;
    alias dchar wchar_t;
    alias dchar wctype_t;
    alias dchar wctrans_t;

    const dchar WEOF = 0xFFFF;
}
