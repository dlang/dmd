/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_rasdlg.d)
 */
module core.sys.windows.rasdlg;

import core.sys.windows.ras;
private import core.sys.windows.lmcons, core.sys.windows.windef;

enum {
	RASPBDEVENT_AddEntry = 1,
	RASPBDEVENT_EditEntry,
	RASPBDEVENT_RemoveEntry,
	RASPBDEVENT_DialEntry,
	RASPBDEVENT_EditGlobals,
	RASPBDEVENT_NoUser,
	RASPBDEVENT_NoUserEdit
}

const RASPBDFLAG_PositionDlg      =  1;
const RASPBDFLAG_ForceCloseOnDial =  2;
const RASPBDFLAG_NoUser           = 16;

const RASEDFLAG_PositionDlg = 1;
const RASEDFLAG_NewEntry    = 2;
const RASEDFLAG_CloneEntry  = 4;

const RASDDFLAG_PositionDlg = 1;

align(4):

struct RASENTRYDLGA {
	DWORD     dwSize = RASENTRYDLGA.sizeof;
	HWND      hwndOwner;
	DWORD     dwFlags;
	LONG      xDlg;
	LONG      yDlg;
	CHAR[RAS_MaxEntryName + 1] szEntry;
	DWORD     dwError;
	ULONG_PTR reserved;
	ULONG_PTR reserved2;
}
alias RASENTRYDLGA* LPRASENTRYDLGA;

struct RASENTRYDLGW {
	DWORD     dwSize = RASENTRYDLGW.sizeof;
	HWND      hwndOwner;
	DWORD     dwFlags;
	LONG      xDlg;
	LONG      yDlg;
	WCHAR[RAS_MaxEntryName + 1] szEntry;
	DWORD     dwError;
	ULONG_PTR reserved;
	ULONG_PTR reserved2;
}
alias RASENTRYDLGW* LPRASENTRYDLGW;

struct RASDIALDLG {
	DWORD     dwSize;
	HWND      hwndOwner;
	DWORD     dwFlags;
	LONG      xDlg;
	LONG      yDlg;
	DWORD     dwSubEntry;
	DWORD     dwError;
	ULONG_PTR reserved;
	ULONG_PTR reserved2;
}
alias RASDIALDLG* LPRASDIALDLG;

// Application-defined callback functions
extern (Windows) {
	alias VOID function(DWORD, DWORD, LPWSTR, LPVOID) RASPBDLGFUNCW;
	alias VOID function(DWORD, DWORD, LPSTR, LPVOID) RASPBDLGFUNCA;
}

struct RASPBDLGA {
	DWORD         dwSize = RASPBDLGA.sizeof;
	HWND          hwndOwner;
	DWORD         dwFlags;
	LONG          xDlg;
	LONG          yDlg;
	ULONG_PTR     dwCallbackId;
	RASPBDLGFUNCA pCallback;
	DWORD         dwError;
	ULONG_PTR     reserved;
	ULONG_PTR     reserved2;
}
alias RASPBDLGA* LPRASPBDLGA;

struct RASPBDLGW {
	DWORD         dwSize = RASPBDLGW.sizeof;
	HWND          hwndOwner;
	DWORD         dwFlags;
	LONG          xDlg;
	LONG          yDlg;
	ULONG_PTR     dwCallbackId;
	RASPBDLGFUNCW pCallback;
	DWORD         dwError;
	ULONG_PTR     reserved;
	ULONG_PTR     reserved2;
}
alias RASPBDLGW* LPRASPBDLGW;

struct RASNOUSERA
{
	DWORD           dwSize = RASNOUSERA.sizeof;
	DWORD           dwFlags;
	DWORD           dwTimeoutMs;
	CHAR[UNLEN + 1] szUserName;
	CHAR[PWLEN + 1] szPassword;
	CHAR[DNLEN + 1] szDomain;
}
alias RASNOUSERA* LPRASNOUSERA;

struct RASNOUSERW {
	DWORD            dwSize = RASNOUSERW.sizeof;
	DWORD            dwFlags;
	DWORD            dwTimeoutMs;
	WCHAR[UNLEN + 1] szUserName;
	WCHAR[PWLEN + 1] szPassword;
	WCHAR[DNLEN + 1] szDomain;
}
alias RASNOUSERW* LPRASNOUSERW;

extern (Windows) {
	BOOL RasDialDlgA(LPSTR, LPSTR, LPSTR, LPRASDIALDLG);
	BOOL RasDialDlgW(LPWSTR, LPWSTR, LPWSTR, LPRASDIALDLG);
	BOOL RasEntryDlgA(LPSTR, LPSTR, LPRASENTRYDLGA);
	BOOL RasEntryDlgW(LPWSTR, LPWSTR, LPRASENTRYDLGW);
	BOOL RasPhonebookDlgA(LPSTR, LPSTR, LPRASPBDLGA);
	BOOL RasPhonebookDlgW(LPWSTR, LPWSTR, LPRASPBDLGW);
}

version (Unicode) {
	alias RASENTRYDLGW RASENTRYDLG;
	alias RASPBDLGW RASPBDLG;
	alias RASNOUSERW RASNOUSER;
	alias RasDialDlgW RasDialDlg;
	alias RasEntryDlgW RasEntryDlg;
	alias RasPhonebookDlgW RasPhonebookDlg;
} else {
	alias RASENTRYDLGA RASENTRYDLG;
	alias RASPBDLGA RASPBDLG;
	alias RASNOUSERA RASNOUSER;
	alias RasDialDlgA RasDialDlg;
	alias RasEntryDlgA RasEntryDlg;
	alias RasPhonebookDlgA RasPhonebookDlg;
}

alias RASENTRYDLG* LPRASENTRYDLG;
alias RASPBDLG* LPRASPBDLG;
alias RASNOUSER* LPRASNOUSER;
