/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC src/core/sys/windows/_richedit.d)
 */
module core.sys.windows.richedit;
version (Windows):

private import core.sys.windows.windef, core.sys.windows.winuser;
private import core.sys.windows.wingdi; // for LF_FACESIZE

align(4):

version(Unicode) {
    const wchar[] RICHEDIT_CLASS = "RichEdit20W";
} else {
    const char[] RICHEDIT_CLASS  = "RichEdit20A";
}

const RICHEDIT_CLASS10A = "RICHEDIT";

const TCHAR[]
    CF_RTF       = "Rich Text Format",
    CF_RTFNOOBJS = "Rich Text Format Without Objects",
    CF_RETEXTOBJ = "RichEdit Text and Objects";

const DWORD
    CFM_BOLD        = 1,
    CFM_ITALIC      = 2,
    CFM_UNDERLINE   = 4,
    CFM_STRIKEOUT   = 8,
    CFM_PROTECTED   = 16,
    CFM_LINK        = 32,
    CFM_SIZE        = 0x80000000,
    CFM_COLOR       = 0x40000000,
    CFM_FACE        = 0x20000000,
    CFM_OFFSET      = 0x10000000,
    CFM_CHARSET     = 0x08000000,
    CFM_SUBSCRIPT   = 0x00030000,
    CFM_SUPERSCRIPT = 0x00030000;

const DWORD
    CFE_BOLD        = 1,
    CFE_ITALIC      = 2,
    CFE_UNDERLINE   = 4,
    CFE_STRIKEOUT   = 8,
    CFE_PROTECTED   = 16,
    CFE_SUBSCRIPT   = 0x00010000,
    CFE_SUPERSCRIPT = 0x00020000,
    CFE_AUTOCOLOR   = 0x40000000;

const CFM_EFFECTS = CFM_BOLD | CFM_ITALIC | CFM_UNDERLINE | CFM_COLOR
  | CFM_STRIKEOUT | CFE_PROTECTED | CFM_LINK;

// flags for EM_SETIMEOPTIONS
const LPARAM
    IMF_FORCENONE         = 1,
    IMF_FORCEENABLE       = 2,
    IMF_FORCEDISABLE      = 4,
    IMF_CLOSESTATUSWINDOW = 8,
    IMF_VERTICAL          = 32,
    IMF_FORCEACTIVE       = 64,
    IMF_FORCEINACTIVE     = 128,
    IMF_FORCEREMEMBER     = 256;

const SEL_EMPTY=0;
const SEL_TEXT=1;
const SEL_OBJECT=2;
const SEL_MULTICHAR=4;
const SEL_MULTIOBJECT=8;

const MAX_TAB_STOPS=32;

const PFM_ALIGNMENT=8;
const PFM_NUMBERING=32;
const PFM_OFFSET=4;
const PFM_OFFSETINDENT=0x80000000;
const PFM_RIGHTINDENT=2;
const PFM_STARTINDENT=1;
const PFM_TABSTOPS=16;
const PFM_BORDER=2048;
const PFM_LINESPACING=256;
const PFM_NUMBERINGSTART=32768;
const PFM_NUMBERINGSTYLE=8192;
const PFM_NUMBERINGTAB=16384;
const PFM_SHADING=4096;
const PFM_SPACEAFTER=128;
const PFM_SPACEBEFORE=64;
const PFM_STYLE=1024;
const PFM_DONOTHYPHEN=4194304;
const PFM_KEEP=131072;
const PFM_KEEPNEXT=262144;
const PFM_NOLINENUMBER=1048576;
const PFM_NOWIDOWCONTROL=2097152;
const PFM_PAGEBREAKBEFORE=524288;
const PFM_RTLPARA=65536;
const PFM_SIDEBYSIDE=8388608;
const PFM_TABLE=1073741824;
const PFN_BULLET=1;

const PFE_DONOTHYPHEN=64;
const PFE_KEEP=2;
const PFE_KEEPNEXT=4;
const PFE_NOLINENUMBER=16;
const PFE_NOWIDOWCONTROL=32;
const PFE_PAGEBREAKBEFORE=8;
const PFE_RTLPARA=1;
const PFE_SIDEBYSIDE=128;
const PFE_TABLE=16384;
const PFA_LEFT=1;
const PFA_RIGHT=2;
const PFA_CENTER=3;
const PFA_JUSTIFY=4;
const PFA_FULL_INTERWORD=4;

const SF_TEXT=1;
const SF_RTF=2;
const SF_RTFNOOBJS=3;
const SF_TEXTIZED=4;
const SF_UNICODE=16;
const SF_USECODEPAGE=32;
const SF_NCRFORNONASCII=64;
const SF_RTFVAL=0x0700;

const SFF_PWD=0x0800;
const SFF_KEEPDOCINFO=0x1000;
const SFF_PERSISTVIEWSCALE=0x2000;
const SFF_PLAINRTF=0x4000;
const SFF_SELECTION=0x8000;

const WB_CLASSIFY      = 3;
const WB_MOVEWORDLEFT  = 4;
const WB_MOVEWORDRIGHT = 5;
const WB_LEFTBREAK     = 6;
const WB_RIGHTBREAK    = 7;
const WB_MOVEWORDPREV  = 4;
const WB_MOVEWORDNEXT  = 5;
const WB_PREVBREAK     = 6;
const WB_NEXTBREAK     = 7;

const WBF_WORDWRAP  = 16;
const WBF_WORDBREAK = 32;
const WBF_OVERFLOW  = 64;
const WBF_LEVEL1    = 128;
const WBF_LEVEL2    = 256;
const WBF_CUSTOM    = 512;

const ES_DISABLENOSCROLL  = 8192;
const ES_SUNKEN           = 16384;
const ES_SAVESEL          = 32768;
const ES_EX_NOCALLOLEINIT = 16777216;
const ES_NOIME            = 524288;
const ES_NOOLEDRAGDROP    = 8;
const ES_SELECTIONBAR     = 16777216;
const ES_SELFIME          = 262144;
const ES_VERTICAL         = 4194304;

const EM_CANPASTE = WM_USER+50;
const EM_DISPLAYBAND = WM_USER+51;
const EM_EXGETSEL = WM_USER+52;
const EM_EXLIMITTEXT = WM_USER+53;
const EM_EXLINEFROMCHAR = WM_USER+54;
const EM_EXSETSEL = WM_USER+55;
const EM_FINDTEXT = WM_USER+56;
const EM_FORMATRANGE = WM_USER+57;
const EM_GETCHARFORMAT = WM_USER+58;
const EM_GETEVENTMASK = WM_USER+59;
const EM_GETOLEINTERFACE = WM_USER+60;
const EM_GETPARAFORMAT = WM_USER+61;
const EM_GETSELTEXT = WM_USER+62;
const EM_HIDESELECTION = WM_USER+63;
const EM_PASTESPECIAL = WM_USER+64;
const EM_REQUESTRESIZE = WM_USER+65;
const EM_SELECTIONTYPE = WM_USER+66;
const EM_SETBKGNDCOLOR = WM_USER+67;
const EM_SETCHARFORMAT = WM_USER+68;
const EM_SETEVENTMASK = WM_USER+69;
const EM_SETOLECALLBACK = WM_USER+70;
const EM_SETPARAFORMAT = WM_USER+71;
const EM_SETTARGETDEVICE = WM_USER+72;
const EM_STREAMIN = WM_USER+73;
const EM_STREAMOUT = WM_USER+74;
const EM_GETTEXTRANGE = WM_USER+75;
const EM_FINDWORDBREAK = WM_USER+76;
const EM_SETOPTIONS = WM_USER+77;
const EM_GETOPTIONS = WM_USER+78;
const EM_FINDTEXTEX = WM_USER+79;
const EM_GETWORDBREAKPROCEX = WM_USER+80;
const EM_SETWORDBREAKPROCEX = WM_USER+81;
/* RichEdit 2.0 messages */
const EM_SETUNDOLIMIT = WM_USER+82;
const EM_REDO = WM_USER+84;
const EM_CANREDO = WM_USER+85;
const EM_GETUNDONAME = WM_USER+86;
const EM_GETREDONAME = WM_USER+87;
const EM_STOPGROUPTYPING = WM_USER+88;
const EM_SETTEXTMODE = WM_USER+89;
const EM_GETTEXTMODE = WM_USER+90;
const EM_AUTOURLDETECT = WM_USER+91;
const EM_GETAUTOURLDETECT = WM_USER + 92;
const EM_SETPALETTE = WM_USER + 93;
const EM_GETTEXTEX = WM_USER+94;
const EM_GETTEXTLENGTHEX = WM_USER+95;
const EM_SHOWSCROLLBAR = WM_USER+96;
const EM_SETTEXTEX = WM_USER + 97;
const EM_SETPUNCTUATION = WM_USER + 100;
const EM_GETPUNCTUATION = WM_USER + 101;
const EM_SETWORDWRAPMODE = WM_USER + 102;
const EM_GETWORDWRAPMODE = WM_USER + 103;
const EM_SETIMECOLOR = WM_USER + 104;
const EM_GETIMECOLOR = WM_USER + 105;
const EM_SETIMEOPTIONS = WM_USER + 106;
const EM_GETIMEOPTIONS = WM_USER + 107;
const EM_SETLANGOPTIONS = WM_USER+120;
const EM_GETLANGOPTIONS = WM_USER+121;
const EM_GETIMECOMPMODE = WM_USER+122;
const EM_FINDTEXTW = WM_USER + 123;
const EM_FINDTEXTEXW = WM_USER + 124;
const EM_RECONVERSION = WM_USER + 125;
const EM_SETBIDIOPTIONS = WM_USER + 200;
const EM_GETBIDIOPTIONS = WM_USER + 201;
const EM_SETTYPOGRAPHYOPTIONS = WM_USER+202;
const EM_GETTYPOGRAPHYOPTIONS = WM_USER+203;
const EM_SETEDITSTYLE = WM_USER + 204;
const EM_GETEDITSTYLE = WM_USER + 205;
const EM_GETSCROLLPOS = WM_USER+221;
const EM_SETSCROLLPOS = WM_USER+222;
const EM_SETFONTSIZE = WM_USER+223;
const EM_GETZOOM = WM_USER+224;
const EM_SETZOOM = WM_USER+225;

const EN_MSGFILTER     = 1792;
const EN_REQUESTRESIZE = 1793;
const EN_SELCHANGE     = 1794;
const EN_DROPFILES     = 1795;
const EN_PROTECTED     = 1796;
const EN_CORRECTTEXT   = 1797;
const EN_STOPNOUNDO    = 1798;
const EN_IMECHANGE     = 1799;
const EN_SAVECLIPBOARD = 1800;
const EN_OLEOPFAILED   = 1801;
const EN_LINK          = 1803;

const ENM_NONE            = 0;
const ENM_CHANGE          = 1;
const ENM_UPDATE          = 2;
const ENM_SCROLL          = 4;
const ENM_SCROLLEVENTS    = 8;
const ENM_DRAGDROPDONE    = 16;
const ENM_KEYEVENTS       = 65536;
const ENM_MOUSEEVENTS     = 131072;
const ENM_REQUESTRESIZE   = 262144;
const ENM_SELCHANGE       = 524288;
const ENM_DROPFILES       = 1048576;
const ENM_PROTECTED       = 2097152;
const ENM_CORRECTTEXT     = 4194304;
const ENM_IMECHANGE       = 8388608;
const ENM_LANGCHANGE      = 16777216;
const ENM_OBJECTPOSITIONS = 33554432;
const ENM_LINK            = 67108864;

const ECO_AUTOWORDSELECTION=1;
const ECO_AUTOVSCROLL=64;
const ECO_AUTOHSCROLL=128;
const ECO_NOHIDESEL=256;
const ECO_READONLY=2048;
const ECO_WANTRETURN=4096;
const ECO_SAVESEL=0x8000;
const ECO_SELECTIONBAR=0x1000000;
const ECO_VERTICAL=0x400000;

enum {
    ECOOP_SET = 1,
    ECOOP_OR,
    ECOOP_AND,
    ECOOP_XOR
}

const SCF_DEFAULT    = 0;
const SCF_SELECTION  = 1;
const SCF_WORD       = 2;
const SCF_ALL        = 4;
const SCF_USEUIRULES = 8;

alias DWORD TEXTMODE;
const TM_PLAINTEXT=1;
const TM_RICHTEXT=2;
const TM_SINGLELEVELUNDO=4;
const TM_MULTILEVELUNDO=8;
const TM_SINGLECODEPAGE=16;
const TM_MULTICODEPAGE=32;

const GT_DEFAULT=0;
const GT_USECRLF=1;

const yHeightCharPtsMost=1638;
const lDefaultTab=720;

alias DWORD UNDONAMEID;
const UID_UNKNOWN    = 0;
const UID_TYPING     = 1;
const UID_DELETE     = 2;
const UID_DRAGDROP   = 3;
const UID_CUT        = 4;
const UID_PASTE      = 5;

struct CHARFORMATA {
    UINT cbSize = this.sizeof;
    DWORD dwMask;
    DWORD dwEffects;
    LONG yHeight;
    LONG yOffset;
    COLORREF crTextColor;
    BYTE bCharSet;
    BYTE bPitchAndFamily;
    char[LF_FACESIZE] szFaceName;
}
struct CHARFORMATW {
    UINT cbSize = this.sizeof;
    DWORD dwMask;
    DWORD dwEffects;
    LONG yHeight;
    LONG yOffset;
    COLORREF crTextColor;
    BYTE bCharSet;
    BYTE bPitchAndFamily;
    WCHAR[LF_FACESIZE] szFaceName;
}

struct CHARFORMAT2A {
    UINT cbSize = this.sizeof;
    DWORD dwMask;
    DWORD dwEffects;
    LONG yHeight;
    LONG yOffset;
    COLORREF crTextColor;
    BYTE bCharSet;
    BYTE bPitchAndFamily;
    char[LF_FACESIZE] szFaceName;
    WORD wWeight;
    SHORT sSpacing;
    COLORREF crBackColor;
    LCID lcid;
    DWORD dwReserved;
    SHORT sStyle;
    WORD wKerning;
    BYTE bUnderlineType;
    BYTE bAnimation;
    BYTE bRevAuthor;
}

struct CHARFORMAT2W {
    UINT cbSize = this.sizeof;
    DWORD dwMask;
    DWORD dwEffects;
    LONG yHeight;
    LONG yOffset;
    COLORREF crTextColor;
    BYTE bCharSet;
    BYTE bPitchAndFamily;
    WCHAR[LF_FACESIZE] szFaceName;
    WORD wWeight;
    SHORT sSpacing;
    COLORREF crBackColor;
    LCID lcid;
    DWORD dwReserved;
    SHORT sStyle;
    WORD wKerning;
    BYTE bUnderlineType;
    BYTE bAnimation;
    BYTE bRevAuthor;
}

struct CHARRANGE {
    LONG cpMin;
    LONG cpMax;
}

struct COMPCOLOR {
    COLORREF crText;
    COLORREF crBackground;
    DWORD dwEffects;
}

extern (Windows) {
    alias DWORD function(DWORD,PBYTE,LONG,LONG*) EDITSTREAMCALLBACK;
}

struct EDITSTREAM {
    DWORD dwCookie;
    DWORD dwError;
    EDITSTREAMCALLBACK pfnCallback;
}

struct ENCORRECTTEXT {
    NMHDR nmhdr;
    CHARRANGE chrg;
    WORD seltyp;
}

struct ENDROPFILES {
    NMHDR nmhdr;
    HANDLE hDrop;
    LONG cp;
    BOOL fProtected;
}

struct ENLINK {
    NMHDR nmhdr;
    UINT msg;
    WPARAM wParam;
    LPARAM lParam;
    CHARRANGE chrg;
}

struct ENOLEOPFAILED {
    NMHDR nmhdr;
    LONG iob;
    LONG lOper;
    HRESULT hr;
}

struct ENPROTECTED {
    NMHDR nmhdr;
    UINT msg;
    WPARAM wParam;
    LPARAM lParam;
    CHARRANGE chrg;
}
alias ENPROTECTED* LPENPROTECTED;

struct ENSAVECLIPBOARD {
    NMHDR nmhdr;
    LONG cObjectCount;
    LONG cch;
}

struct FINDTEXTA {
    CHARRANGE chrg;
    LPSTR lpstrText;
}

struct FINDTEXTW {
    CHARRANGE chrg;
    LPWSTR lpstrText;
}

struct FINDTEXTEXA {
    CHARRANGE chrg;
    LPSTR lpstrText;
    CHARRANGE chrgText;
}

struct FINDTEXTEXW {
    CHARRANGE chrg;
    LPWSTR lpstrText;
    CHARRANGE chrgText;
}

struct FORMATRANGE {
    HDC hdc;
    HDC hdcTarget;
    RECT rc;
    RECT rcPage;
    CHARRANGE chrg;
}

struct MSGFILTER {
    NMHDR nmhdr;
    UINT msg;
    WPARAM wParam;
    LPARAM lParam;
}

struct PARAFORMAT {
    UINT cbSize = this.sizeof;
    DWORD dwMask;
    WORD wNumbering;
    WORD wReserved;
    LONG dxStartIndent;
    LONG dxRightIndent;
    LONG dxOffset;
    WORD wAlignment;
    SHORT cTabCount;
    LONG[MAX_TAB_STOPS] rgxTabs;
}

struct PARAFORMAT2 {
    UINT cbSize = this.sizeof;
    DWORD dwMask;
    WORD wNumbering;
    WORD wEffects;
    LONG dxStartIndent;
    LONG dxRightIndent;
    LONG dxOffset;
    WORD wAlignment;
    SHORT cTabCount;
    LONG[MAX_TAB_STOPS] rgxTabs;
    LONG dySpaceBefore;
    LONG dySpaceAfter;
    LONG dyLineSpacing;
    SHORT sStype;
    BYTE bLineSpacingRule;
    BYTE bOutlineLevel;
    WORD wShadingWeight;
    WORD wShadingStyle;
    WORD wNumberingStart;
    WORD wNumberingStyle;
    WORD wNumberingTab;
    WORD wBorderSpace;
    WORD wBorderWidth;
    WORD wBorders;
}

struct SELCHANGE {
    NMHDR nmhdr;
    CHARRANGE chrg;
    WORD seltyp;
}

struct TEXTRANGEA {
    CHARRANGE chrg;
    LPSTR lpstrText;
}

struct TEXTRANGEW {
    CHARRANGE chrg;
    LPWSTR lpstrText;
}

struct REQRESIZE {
    NMHDR nmhdr;
    RECT rc;
}

struct REPASTESPECIAL {
    DWORD dwAspect;
    DWORD dwParam;
}

struct PUNCTUATION {
    UINT iSize;
    LPSTR szPunctuation;
}

struct GETTEXTEX {
    DWORD cb;
    DWORD flags;
    UINT codepage;
    LPCSTR lpDefaultChar;
    LPBOOL lpUsedDefChar;
}

extern (Windows) {
alias LONG function(char*,LONG,BYTE,INT) EDITWORDBREAKPROCEX;
}

/* Defines for EM_SETTYPOGRAPHYOPTIONS */
const TO_ADVANCEDTYPOGRAPHY = 1;
const TO_SIMPLELINEBREAK    = 2;

/* Defines for GETTEXTLENGTHEX */
const GTL_DEFAULT  = 0;
const GTL_USECRLF  = 1;
const GTL_PRECISE  = 2;
const GTL_CLOSE    = 4;
const GTL_NUMCHARS = 8;
const GTL_NUMBYTES = 16;

struct GETTEXTLENGTHEX {
    DWORD flags;
    UINT codepage;
}

version(Unicode) {
    alias CHARFORMATW CHARFORMAT;
    alias CHARFORMAT2W CHARFORMAT2;
    alias FINDTEXTW FINDTEXT;
    alias FINDTEXTEXW FINDTEXTEX;
    alias TEXTRANGEW TEXTRANGE;
} else {
    alias CHARFORMATA CHARFORMAT;
    alias CHARFORMAT2A CHARFORMAT2;
    alias FINDTEXTA FINDTEXT;
    alias FINDTEXTEXA FINDTEXTEX;
    alias TEXTRANGEA TEXTRANGE;
}
