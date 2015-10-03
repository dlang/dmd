/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_cpl.d)
 */
module core.sys.windows.cpl;

private import core.sys.windows.windef, core.sys.windows.winuser;

enum : uint {
	WM_CPL_LAUNCH = WM_USER + 1000,
	WM_CPL_LAUNCHED
}

enum : uint {
	CPL_DYNAMIC_RES,
	CPL_INIT,
	CPL_GETCOUNT,
	CPL_INQUIRE,
	CPL_SELECT,
	CPL_DBLCLK,
	CPL_STOP,
	CPL_EXIT,
	CPL_NEWINQUIRE,
	CPL_STARTWPARMSA,
	CPL_STARTWPARMSW, // = 10
	CPL_SETUP = 200
}

extern (Windows) alias LONG function(HWND, UINT, LONG, LONG) APPLET_PROC;

struct CPLINFO {
	int  idIcon;
	int  idName;
	int  idInfo;
	LONG lData;
}
alias CPLINFO* LPCPLINFO;

struct NEWCPLINFOA {
	DWORD     dwSize = NEWCPLINFOA.sizeof;
	DWORD     dwFlags;
	DWORD     dwHelpContext;
	LONG      lData;
	HICON     hIcon;
	CHAR[32]  szName;
	CHAR[64]  szInfo;
	CHAR[128] szHelpFile;
}
alias NEWCPLINFOA* LPNEWCPLINFOA;

struct NEWCPLINFOW {
	DWORD      dwSize = NEWCPLINFOW.sizeof;
	DWORD      dwFlags;
	DWORD      dwHelpContext;
	LONG       lData;
	HICON      hIcon;
	WCHAR[32]  szName;
	WCHAR[64]  szInfo;
	WCHAR[128] szHelpFile;
}
alias NEWCPLINFOW* LPNEWCPLINFOW;

version (Unicode) {
	alias CPL_STARTWPARMSW CPL_STARTWPARMS;
	alias NEWCPLINFOW NEWCPLINFO;
} else {
	alias CPL_STARTWPARMSA CPL_STARTWPARMS;
	alias NEWCPLINFOA NEWCPLINFO;
}

alias NEWCPLINFO* LPNEWCPLINFO;
