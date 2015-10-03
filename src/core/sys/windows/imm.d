/***********************************************************************\
*                                 imm.d                                 *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.imm;
pragma(lib, "imm32");

import win32.windef, win32.wingdi;
import win32.winuser; // for the MFS_xxx enums.
private import win32.w32api;

const WM_CONVERTREQUESTEX     = 0x108;
const WM_IME_STARTCOMPOSITION = 0x10D;
const WM_IME_ENDCOMPOSITION   = 0x10E;
const WM_IME_COMPOSITION      = 0x10F;
const WM_IME_KEYLAST          = 0x10F;
const WM_IME_SETCONTEXT       = 0x281;
const WM_IME_NOTIFY           = 0x282;
const WM_IME_CONTROL          = 0x283;
const WM_IME_COMPOSITIONFULL  = 0x284;
const WM_IME_SELECT           = 0x285;
const WM_IME_CHAR             = 0x286;
static if (_WIN32_WINNT >= 0x500) {
	const WM_IME_REQUEST      = 0x288;
}
const WM_IME_KEYDOWN          = 0x290;
const WM_IME_KEYUP            = 0x291;


const IMC_GETCANDIDATEPOS=7;
const IMC_SETCANDIDATEPOS=8;
const IMC_GETCOMPOSITIONFONT=9;
const IMC_SETCOMPOSITIONFONT=10;
const IMC_GETCOMPOSITIONWINDOW=11;
const IMC_SETCOMPOSITIONWINDOW=12;
const IMC_GETSTATUSWINDOWPOS=15;
const IMC_SETSTATUSWINDOWPOS=16;
const IMC_CLOSESTATUSWINDOW=0x21;
const IMC_OPENSTATUSWINDOW=0x22;
const IMN_CLOSESTATUSWINDOW=1;
const IMN_OPENSTATUSWINDOW=2;
const IMN_CHANGECANDIDATE=3;
const IMN_CLOSECANDIDATE=4;
const IMN_OPENCANDIDATE=5;
const IMN_SETCONVERSIONMODE=6;
const IMN_SETSENTENCEMODE=7;
const IMN_SETOPENSTATUS=8;
const IMN_SETCANDIDATEPOS=9;
const IMN_SETCOMPOSITIONFONT=10;
const IMN_SETCOMPOSITIONWINDOW=11;
const IMN_SETSTATUSWINDOWPOS=12;
const IMN_GUIDELINE=13;
const IMN_PRIVATE=14;

const NI_OPENCANDIDATE=16;
const NI_CLOSECANDIDATE=17;
const NI_SELECTCANDIDATESTR=18;
const NI_CHANGECANDIDATELIST=19;
const NI_FINALIZECONVERSIONRESULT=20;
const NI_COMPOSITIONSTR=21;
const NI_SETCANDIDATE_PAGESTART=22;
const NI_SETCANDIDATE_PAGESIZE=23;
const NI_IMEMENUSELECTED=24;

const ISC_SHOWUICANDIDATEWINDOW=1;
const ISC_SHOWUICOMPOSITIONWINDOW=0x80000000;
const ISC_SHOWUIGUIDELINE=0x40000000;
const ISC_SHOWUIALLCANDIDATEWINDOW=15;
const ISC_SHOWUIALL=0xC000000F;

const CPS_COMPLETE=1;
const CPS_CONVERT=2;
const CPS_REVERT=3;
const CPS_CANCEL=4;

const IME_CHOTKEY_IME_NONIME_TOGGLE=16;
const IME_CHOTKEY_SHAPE_TOGGLE=17;
const IME_CHOTKEY_SYMBOL_TOGGLE=18;
const IME_JHOTKEY_CLOSE_OPEN=0x30;
const IME_KHOTKEY_SHAPE_TOGGLE=0x50;
const IME_KHOTKEY_HANJACONVERT=0x51;
const IME_KHOTKEY_ENGLISH=0x52;
const IME_THOTKEY_IME_NONIME_TOGGLE=0x70;
const IME_THOTKEY_SHAPE_TOGGLE=0x71;
const IME_THOTKEY_SYMBOL_TOGGLE=0x72;
const IME_HOTKEY_DSWITCH_FIRST=256;
const IME_HOTKEY_DSWITCH_LAST=0x11F;
const IME_ITHOTKEY_RESEND_RESULTSTR=512;
const IME_ITHOTKEY_PREVIOUS_COMPOSITION=513;
const IME_ITHOTKEY_UISTYLE_TOGGLE=514;

const GCS_COMPREADSTR=1;
const GCS_COMPREADATTR=2;
const GCS_COMPREADCLAUSE=4;
const GCS_COMPSTR=8;
const GCS_COMPATTR=16;
const GCS_COMPCLAUSE=32;
const GCS_CURSORPOS=128;
const GCS_DELTASTART=256;
const GCS_RESULTREADSTR=512;
const GCS_RESULTREADCLAUSE=1024;
const GCS_RESULTSTR=2048;
const GCS_RESULTCLAUSE=4096;

const CS_INSERTCHAR=0x2000;
const CS_NOMOVECARET=0x4000;

const IMEVER_0310=0x3000A;
const IMEVER_0400=0x40000;

const IME_PROP_AT_CARET=0x10000;
const IME_PROP_SPECIAL_UI=0x20000;
const IME_PROP_CANDLIST_START_FROM_1=0x40000;
const IME_PROP_UNICODE=0x80000;

const UI_CAP_2700=1;
const UI_CAP_ROT90=2;
const UI_CAP_ROTANY=4;

const SCS_CAP_COMPSTR=1;
const SCS_CAP_MAKEREAD=2;
const SELECT_CAP_CONVERSION=1;
const SELECT_CAP_SENTENCE=2;
const GGL_LEVEL=1;
const GGL_INDEX=2;
const GGL_STRING=3;
const GGL_PRIVATE=4;
const GL_LEVEL_NOGUIDELINE=0;
const GL_LEVEL_FATAL=1;
const GL_LEVEL_ERROR=2;
const GL_LEVEL_WARNING=3;
const GL_LEVEL_INFORMATION=4;
const GL_ID_UNKNOWN=0;
const GL_ID_NOMODULE=1;
const GL_ID_NODICTIONARY=16;
const GL_ID_CANNOTSAVE=17;
const GL_ID_NOCONVERT=32;
const GL_ID_TYPINGERROR=33;
const GL_ID_TOOMANYSTROKE=34;
const GL_ID_READINGCONFLICT=35;
const GL_ID_INPUTREADING=36;
const GL_ID_INPUTRADICAL=37;
const GL_ID_INPUTCODE=38;
const GL_ID_INPUTSYMBOL=39;
const GL_ID_CHOOSECANDIDATE=40;
const GL_ID_REVERSECONVERSION=41;
const GL_ID_PRIVATE_FIRST=0x8000;
const GL_ID_PRIVATE_LAST=0xFFFF;

const DWORD IGP_GETIMEVERSION = -4;
const IGP_PROPERTY=4;
const IGP_CONVERSION=8;
const IGP_SENTENCE=12;
const IGP_UI=16;
const IGP_SETCOMPSTR=0x14;
const IGP_SELECT=0x18;

const SCS_SETSTR       = GCS_COMPREADSTR|GCS_COMPSTR;
const SCS_CHANGEATTR   = GCS_COMPREADATTR|GCS_COMPATTR;
const SCS_CHANGECLAUSE = GCS_COMPREADCLAUSE|GCS_COMPCLAUSE;

const ATTR_INPUT=0;
const ATTR_TARGET_CONVERTED=1;
const ATTR_CONVERTED=2;
const ATTR_TARGET_NOTCONVERTED=3;
const ATTR_INPUT_ERROR=4;
const ATTR_FIXEDCONVERTED=5;
const CFS_DEFAULT=0;
const CFS_RECT=1;
const CFS_POINT=2;
const CFS_SCREEN=4;
const CFS_FORCE_POSITION=32;
const CFS_CANDIDATEPOS=64;
const CFS_EXCLUDE=128;
const GCL_CONVERSION=1;
const GCL_REVERSECONVERSION=2;
const GCL_REVERSE_LENGTH=3;

const IME_CMODE_ALPHANUMERIC=0;
const IME_CMODE_NATIVE=1;
const IME_CMODE_CHINESE=IME_CMODE_NATIVE;
const IME_CMODE_HANGEUL=IME_CMODE_NATIVE;
const IME_CMODE_HANGUL=IME_CMODE_NATIVE;
const IME_CMODE_JAPANESE=IME_CMODE_NATIVE;
const IME_CMODE_KATAKANA=2;
const IME_CMODE_LANGUAGE=3;
const IME_CMODE_FULLSHAPE=8;
const IME_CMODE_ROMAN=16;
const IME_CMODE_CHARCODE=32;
const IME_CMODE_HANJACONVERT=64;
const IME_CMODE_SOFTKBD=128;
const IME_CMODE_NOCONVERSION=256;
const IME_CMODE_EUDC=512;
const IME_CMODE_SYMBOL=1024;
const IME_CMODE_FIXED=2048;
const IME_SMODE_NONE=0;
const IME_SMODE_PLAURALCLAUSE=1;
const IME_SMODE_SINGLECONVERT=2;
const IME_SMODE_AUTOMATIC=4;
const IME_SMODE_PHRASEPREDICT=8;
const IME_CAND_UNKNOWN=0;
const IME_CAND_READ=1;
const IME_CAND_CODE=2;
const IME_CAND_MEANING=3;
const IME_CAND_RADICAL=4;
const IME_CAND_STROKE=5;
const IMM_ERROR_NODATA=(-1);
const IMM_ERROR_GENERAL=(-2);
const IME_CONFIG_GENERAL=1;
const IME_CONFIG_REGISTERWORD=2;
const IME_CONFIG_SELECTDICTIONARY=3;
const IME_ESC_QUERY_SUPPORT=3;
const IME_ESC_RESERVED_FIRST=4;
const IME_ESC_RESERVED_LAST=0x7FF;
const IME_ESC_PRIVATE_FIRST=0x800;
const IME_ESC_PRIVATE_LAST=0xFFF;
const IME_ESC_SEQUENCE_TO_INTERNAL=0x1001;
const IME_ESC_GET_EUDC_DICTIONARY=0x1003;
const IME_ESC_SET_EUDC_DICTIONARY=0x1004;
const IME_ESC_MAX_KEY=0x1005;
const IME_ESC_IME_NAME=0x1006;
const IME_ESC_SYNC_HOTKEY=0x1007;
const IME_ESC_HANJA_MODE=0x1008;
const IME_ESC_AUTOMATA=0x1009;
const IME_REGWORD_STYLE_EUDC=1;
const IME_REGWORD_STYLE_USER_FIRST=0x80000000;
const IME_REGWORD_STYLE_USER_LAST=0xFFFFFFFF;

const SOFTKEYBOARD_TYPE_T1=1;
const SOFTKEYBOARD_TYPE_C1=2;

const IMEMENUITEM_STRING_SIZE=80;

const MOD_ALT=1;
const MOD_CONTROL=2;
const MOD_SHIFT=4;
const MOD_WIN=8;
const MOD_IGNORE_ALL_MODIFIER=1024;
const MOD_ON_KEYUP=2048;
const MOD_RIGHT=16384;
const MOD_LEFT=32768;

const IACE_CHILDREN=1;
const IACE_DEFAULT=16;
const IACE_IGNORENOCONTEXT=32;

const IGIMIF_RIGHTMENU=1;

const IGIMII_CMODE=1;
const IGIMII_SMODE=2;
const IGIMII_CONFIGURE=4;
const IGIMII_TOOLS=8;
const IGIMII_HELP=16;
const IGIMII_OTHER=32;
const IGIMII_INPUTTOOLS=64;

const IMFT_RADIOCHECK=1;
const IMFT_SEPARATOR=2;
const IMFT_SUBMENU=4;

const IMFS_GRAYED=MFS_GRAYED;
const IMFS_DISABLED=MFS_DISABLED;
const IMFS_CHECKED=MFS_CHECKED;
const IMFS_HILITE=MFS_HILITE;
const IMFS_ENABLED=MFS_ENABLED;
const IMFS_UNCHECKED=MFS_UNCHECKED;
const IMFS_UNHILITE=MFS_UNHILITE;
const IMFS_DEFAULT=MFS_DEFAULT;

const STYLE_DESCRIPTION_SIZE=32;

alias DWORD HIMC;
alias DWORD HIMCC;
alias HKL* LPHKL;

struct COMPOSITIONFORM{
	DWORD dwStyle;
	POINT ptCurrentPos;
	RECT rcArea;
}
alias COMPOSITIONFORM* PCOMPOSITIONFORM, LPCOMPOSITIONFORM;

struct CANDIDATEFORM{
	DWORD dwIndex;
	DWORD dwStyle;
	POINT ptCurrentPos;
	RECT rcArea;
}
alias CANDIDATEFORM* PCANDIDATEFORM, LPCANDIDATEFORM;

struct CANDIDATELIST{
	DWORD dwSize;
	DWORD dwStyle;
	DWORD dwCount;
	DWORD dwSelection;
	DWORD dwPageStart;
	DWORD dwPageSize;
	DWORD[1] dwOffset;
}
alias CANDIDATELIST* PCANDIDATELIST, LPCANDIDATELIST;

struct REGISTERWORDA{
	LPSTR lpReading;
	LPSTR lpWord;
}
alias REGISTERWORDA* PREGISTERWORDA, LPREGISTERWORDA;

struct REGISTERWORDW{
	LPWSTR lpReading;
	LPWSTR lpWord;
}
alias REGISTERWORDW* PREGISTERWORDW, LPREGISTERWORDW;

struct STYLEBUFA{
	DWORD dwStyle;
	CHAR[STYLE_DESCRIPTION_SIZE] szDescription;
}
alias STYLEBUFA* PSTYLEBUFA, LPSTYLEBUFA;

struct STYLEBUFW{
	DWORD dwStyle;
	WCHAR[STYLE_DESCRIPTION_SIZE] szDescription;
}
alias STYLEBUFW* PSTYLEBUFW, LPSTYLEBUFW;

struct IMEMENUITEMINFOA{
	UINT cbSize = this.sizeof;
	UINT fType;
	UINT fState;
	UINT wID;
	HBITMAP hbmpChecked;
	HBITMAP hbmpUnchecked;
	DWORD dwItemData;
	CHAR[IMEMENUITEM_STRING_SIZE] szString;
	HBITMAP hbmpItem;
}
alias IMEMENUITEMINFOA* PIMEMENUITEMINFOA, LPIMEMENUITEMINFOA;

struct IMEMENUITEMINFOW{
	UINT cbSize = this.sizeof;
	UINT fType;
	UINT fState;
	UINT wID;
	HBITMAP hbmpChecked;
	HBITMAP hbmpUnchecked;
	DWORD dwItemData;
	WCHAR[IMEMENUITEM_STRING_SIZE] szString;
	HBITMAP hbmpItem;
}
alias IMEMENUITEMINFOW* PIMEMENUITEMINFOW, LPIMEMENUITEMINFOW;

alias int function (LPCSTR, DWORD, LPCSTR, LPVOID)  REGISTERWORDENUMPROCA;
alias int function (LPCWSTR, DWORD, LPCWSTR, LPVOID) REGISTERWORDENUMPROCW;

version(Unicode) {
	alias REGISTERWORDENUMPROCW REGISTERWORDENUMPROC;
	alias REGISTERWORDW REGISTERWORD;
	alias IMEMENUITEMINFOW IMEMENUITEMINFO;
	alias STYLEBUFW STYLEBUF;
} else {
	alias REGISTERWORDENUMPROCA REGISTERWORDENUMPROC;
	alias REGISTERWORDA REGISTERWORD;
	alias IMEMENUITEMINFOA IMEMENUITEMINFO;
	alias STYLEBUFA STYLEBUF;
}

alias STYLEBUF* PSTYLEBUF, LPSTYLEBUF;
alias REGISTERWORD* PREGISTERWORD, LPREGISTERWORD;
alias IMEMENUITEMINFO* PIMEMENUITEMINFO, LPIMEMENUITEMINFO;


extern (Windows):
HKL ImmInstallIMEA(LPCSTR, LPCSTR);
HKL ImmInstallIMEW(LPCWSTR, LPCWSTR);
HWND ImmGetDefaultIMEWnd(HWND);
UINT ImmGetDescriptionA(HKL, LPSTR, UINT);
UINT ImmGetDescriptionW(HKL, LPWSTR, UINT);
UINT ImmGetIMEFileNameA(HKL, LPSTR, UINT);
UINT ImmGetIMEFileNameW(HKL, LPWSTR, UINT);
DWORD ImmGetProperty(HKL, DWORD);
BOOL ImmIsIME(HKL);
BOOL ImmSimulateHotKey(HWND, DWORD);
HIMC ImmCreateContext();
BOOL ImmDestroyContext(HIMC);
HIMC ImmGetContext(HWND);
BOOL ImmReleaseContext(HWND, HIMC);
HIMC ImmAssociateContext(HWND, HIMC);
LONG ImmGetCompositionStringA(HIMC, DWORD, PVOID, DWORD);
LONG ImmGetCompositionStringW(HIMC, DWORD, PVOID, DWORD);
BOOL ImmSetCompositionStringA(HIMC, DWORD, PCVOID, DWORD, PCVOID, DWORD);
BOOL ImmSetCompositionStringW(HIMC, DWORD, PCVOID, DWORD, PCVOID, DWORD);
DWORD ImmGetCandidateListCountA(HIMC, PDWORD);
DWORD ImmGetCandidateListCountW(HIMC, PDWORD);
DWORD ImmGetCandidateListA(HIMC, DWORD, PCANDIDATELIST, DWORD);
DWORD ImmGetCandidateListW(HIMC, DWORD, PCANDIDATELIST, DWORD);
DWORD ImmGetGuideLineA(HIMC, DWORD, LPSTR, DWORD);
DWORD ImmGetGuideLineW(HIMC, DWORD, LPWSTR, DWORD);
BOOL ImmGetConversionStatus(HIMC, LPDWORD, PDWORD);
BOOL ImmSetConversionStatus(HIMC, DWORD, DWORD);
BOOL ImmGetOpenStatus(HIMC);
BOOL ImmSetOpenStatus(HIMC, BOOL);

BOOL ImmGetCompositionFontA(HIMC, LPLOGFONTA);
BOOL ImmGetCompositionFontW(HIMC, LPLOGFONTW);
BOOL ImmSetCompositionFontA(HIMC, LPLOGFONTA);
BOOL ImmSetCompositionFontW(HIMC, LPLOGFONTW);

BOOL ImmConfigureIMEA(HKL, HWND, DWORD, PVOID);
BOOL ImmConfigureIMEW(HKL, HWND, DWORD, PVOID);
LRESULT ImmEscapeA(HKL, HIMC, UINT, PVOID);
LRESULT ImmEscapeW(HKL, HIMC, UINT, PVOID);
DWORD ImmGetConversionListA(HKL, HIMC, LPCSTR, PCANDIDATELIST, DWORD, UINT);
DWORD ImmGetConversionListW(HKL, HIMC, LPCWSTR, PCANDIDATELIST, DWORD, UINT);
BOOL ImmNotifyIME(HIMC, DWORD, DWORD, DWORD);
BOOL ImmGetStatusWindowPos(HIMC, LPPOINT);
BOOL ImmSetStatusWindowPos(HIMC, LPPOINT);
BOOL ImmGetCompositionWindow(HIMC, PCOMPOSITIONFORM);
BOOL ImmSetCompositionWindow(HIMC, PCOMPOSITIONFORM);
BOOL ImmGetCandidateWindow(HIMC, DWORD, PCANDIDATEFORM);
BOOL ImmSetCandidateWindow(HIMC, PCANDIDATEFORM);
BOOL ImmIsUIMessageA(HWND, UINT, WPARAM, LPARAM);
BOOL ImmIsUIMessageW(HWND, UINT, WPARAM, LPARAM);
UINT ImmGetVirtualKey(HWND);
BOOL ImmRegisterWordA(HKL, LPCSTR, DWORD, LPCSTR);
BOOL ImmRegisterWordW(HKL, LPCWSTR, DWORD, LPCWSTR);
BOOL ImmUnregisterWordA(HKL, LPCSTR, DWORD, LPCSTR);
BOOL ImmUnregisterWordW(HKL, LPCWSTR, DWORD, LPCWSTR);
UINT ImmGetRegisterWordStyleA(HKL, UINT, PSTYLEBUFA);
UINT ImmGetRegisterWordStyleW(HKL, UINT, PSTYLEBUFW);
UINT ImmEnumRegisterWordA(HKL, REGISTERWORDENUMPROCA, LPCSTR, DWORD, LPCSTR, PVOID);
UINT ImmEnumRegisterWordW(HKL, REGISTERWORDENUMPROCW, LPCWSTR, DWORD, LPCWSTR, PVOID);
BOOL EnableEUDC(BOOL);
BOOL ImmDisableIME(DWORD);
DWORD ImmGetImeMenuItemsA(HIMC, DWORD, DWORD, LPIMEMENUITEMINFOA, LPIMEMENUITEMINFOA, DWORD);
DWORD ImmGetImeMenuItemsW(HIMC, DWORD, DWORD, LPIMEMENUITEMINFOW, LPIMEMENUITEMINFOW, DWORD);

version(Unicode) {
	alias ImmEnumRegisterWordW ImmEnumRegisterWord;
	alias ImmGetRegisterWordStyleW ImmGetRegisterWordStyle;
	alias ImmUnregisterWordW ImmUnregisterWord;
	alias ImmRegisterWordW ImmRegisterWord;
	alias ImmInstallIMEW ImmInstallIME;
	alias ImmIsUIMessageW ImmIsUIMessage;
	alias ImmGetConversionListW ImmGetConversionList;
	alias ImmEscapeW ImmEscape;
	alias ImmConfigureIMEW ImmConfigureIME;
	alias ImmSetCompositionFontW ImmSetCompositionFont;
	alias ImmGetCompositionFontW ImmGetCompositionFont;
	alias ImmGetGuideLineW ImmGetGuideLine;
	alias ImmGetCandidateListW ImmGetCandidateList;
	alias ImmGetCandidateListCountW ImmGetCandidateListCount;
	alias ImmSetCompositionStringW ImmSetCompositionString;
	alias ImmGetCompositionStringW ImmGetCompositionString;
	alias ImmGetDescriptionW ImmGetDescription;
	alias ImmGetIMEFileNameW ImmGetIMEFileName;
	alias ImmGetImeMenuItemsW ImmGetImeMenuItems;
} else {
	alias ImmEnumRegisterWordA ImmEnumRegisterWord;
	alias ImmGetRegisterWordStyleA ImmGetRegisterWordStyle;
	alias ImmUnregisterWordA ImmUnregisterWord;
	alias ImmRegisterWordA ImmRegisterWord;
	alias ImmInstallIMEA ImmInstallIME;
	alias ImmIsUIMessageA ImmIsUIMessage;
	alias ImmGetConversionListA ImmGetConversionList;
	alias ImmEscapeA ImmEscape;
	alias ImmConfigureIMEA ImmConfigureIME;
	alias ImmSetCompositionFontA ImmSetCompositionFont;
	alias ImmGetCompositionFontA ImmGetCompositionFont;
	alias ImmGetGuideLineA ImmGetGuideLine;
	alias ImmGetCandidateListA ImmGetCandidateList;
	alias ImmGetCandidateListCountA ImmGetCandidateListCount;
	alias ImmSetCompositionStringA ImmSetCompositionString;
	alias ImmGetCompositionStringA ImmGetCompositionString;
	alias ImmGetDescriptionA ImmGetDescription;
	alias ImmGetIMEFileNameA ImmGetIMEFileName;
	alias ImmGetImeMenuItemsW ImmGetImeMenuItems;
}
