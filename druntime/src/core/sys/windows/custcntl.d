/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_custcntl.d)
 */
module core.sys.windows.custcntl;
version (Windows):

version (ANSI) {} else version = Unicode;

import core.sys.windows.windef;

// FIXME: check type
enum CCF_NOTEXT = 1;

enum size_t
    CCHCCCLASS =  32,
    CCHCCDESC  =  32,
    CCHCCTEXT  = 256;

struct CCSTYLEA {
    DWORD           flStyle;
    DWORD           flExtStyle;
    CHAR[CCHCCTEXT] szText = 0;
    LANGID          lgid;
    WORD            wReserved1;
}
alias LPCCSTYLEA = CCSTYLEA*;

struct CCSTYLEW {
    DWORD            flStyle;
    DWORD            flExtStyle;
    WCHAR[CCHCCTEXT] szText = 0;
    LANGID           lgid;
    WORD             wReserved1;
}
alias LPCCSTYLEW = CCSTYLEW*;

struct CCSTYLEFLAGA {
    DWORD flStyle;
    DWORD flStyleMask;
    LPSTR pszStyle;
}
alias LPCCSTYLEFLAGA = CCSTYLEFLAGA*;

struct CCSTYLEFLAGW {
    DWORD  flStyle;
    DWORD  flStyleMask;
    LPWSTR pszStyle;
}
alias LPCCSTYLEFLAGW = CCSTYLEFLAGW*;

struct CCINFOA {
    CHAR[CCHCCCLASS]  szClass = 0;
    DWORD             flOptions;
    CHAR[CCHCCDESC]   szDesc = 0;
    UINT              cxDefault;
    UINT              cyDefault;
    DWORD             flStyleDefault;
    DWORD             flExtStyleDefault;
    DWORD             flCtrlTypeMask;
    CHAR[CCHCCTEXT]   szTextDefault = 0;
    INT               cStyleFlags;
    LPCCSTYLEFLAGA    aStyleFlags;
    LPFNCCSTYLEA      lpfnStyle;
    LPFNCCSIZETOTEXTA lpfnSizeToText;
    DWORD             dwReserved1;
    DWORD             dwReserved2;
}
alias LPCCINFOA = CCINFOA*;

struct CCINFOW {
    WCHAR[CCHCCCLASS] szClass = 0;
    DWORD             flOptions;
    WCHAR[CCHCCDESC]  szDesc = 0;
    UINT              cxDefault;
    UINT              cyDefault;
    DWORD             flStyleDefault;
    DWORD             flExtStyleDefault;
    DWORD             flCtrlTypeMask;
    WCHAR[CCHCCTEXT]  szTextDefault = 0;
    INT               cStyleFlags;
    LPCCSTYLEFLAGW    aStyleFlags;
    LPFNCCSTYLEW      lpfnStyle;
    LPFNCCSIZETOTEXTW lpfnSizeToText;
    DWORD             dwReserved1;
    DWORD             dwReserved2;
}
alias LPCCINFOW = CCINFOW*;

extern (Windows) {
    alias LPFNCCSTYLEA = BOOL function(HWND, LPCCSTYLEA);
    alias LPFNCCSTYLEW = BOOL function(HWND, LPCCSTYLEW);
    alias LPFNCCSIZETOTEXTA = INT function(DWORD, DWORD, HFONT, LPSTR);
    alias LPFNCCSIZETOTEXTW = INT function(DWORD, DWORD, HFONT, LPWSTR);
    alias LPFNCCINFOA = UINT function(LPCCINFOA);
    alias LPFNCCINFOW = UINT function(LPCCINFOW);
nothrow @nogc:
    UINT CustomControlInfoA(LPCCINFOA acci);
    UINT CustomControlInfoW(LPCCINFOW acci);
}

version (Unicode) {
    alias CCSTYLE = CCSTYLEW;
    alias CCSTYLEFLAG = CCSTYLEFLAGW;
    alias CCINFO = CCINFOW;
    alias LPFNCCSTYLE = LPFNCCSTYLEW;
    alias LPFNCCSIZETOTEXT = LPFNCCSIZETOTEXTW;
    alias LPFNCCINFO = LPFNCCINFOW;
} else {
    alias CCSTYLE = CCSTYLEA;
    alias CCSTYLEFLAG = CCSTYLEFLAGA;
    alias CCINFO = CCINFOA;
    alias LPFNCCSTYLE = LPFNCCSTYLEA;
    alias LPFNCCSIZETOTEXT = LPFNCCSIZETOTEXTA;
    alias LPFNCCINFO = LPFNCCINFOA;
}

alias LPCCSTYLE = CCSTYLE*;
alias LPCCSTYLEFLAG = CCSTYLEFLAG*;
alias LPCCINFO = CCINFO*;
