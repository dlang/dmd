/***********************************************************************\
*                               lmremutl.d                              *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.lmremutl;
pragma(lib, "netapi32");

// D Conversion Note: DESC_CHAR is defined as TCHAR.

private import win32.lmcons, win32.windef;

const SUPPORTS_REMOTE_ADMIN_PROTOCOL =  2;
const SUPPORTS_RPC                   =  4;
const SUPPORTS_SAM_PROTOCOL          =  8;
const SUPPORTS_UNICODE               = 16;
const SUPPORTS_LOCAL                 = 32;
const SUPPORTS_ANY                   = 0xFFFFFFFF;

const NO_PERMISSION_REQUIRED = 1;
const ALLOCATE_RESPONSE      = 2;
const USE_SPECIFIC_TRANSPORT = 0x80000000;

//[Yes] #ifndef DESC_CHAR_UNICODE
//alias CHAR DESC_CHAR;
//} else {
//[No] #else
//[No] typedef WCHAR DESC_CHAR;
//[No] #endif
// FIXME (D): Is this OK?
alias TCHAR DESC_CHAR;

alias DESC_CHAR* LPDESC;

struct TIME_OF_DAY_INFO {
	DWORD tod_elapsedt;
	DWORD tod_msecs;
	DWORD tod_hours;
	DWORD tod_mins;
	DWORD tod_secs;
	DWORD tod_hunds;
	LONG  tod_timezone;
	DWORD tod_tinterval;
	DWORD tod_day;
	DWORD tod_month;
	DWORD tod_year;
	DWORD tod_weekday;
}
alias TIME_OF_DAY_INFO* PTIME_OF_DAY_INFO, LPTIME_OF_DAY_INFO;

extern (Windows) {
	NET_API_STATUS NetRemoteTOD(LPCWSTR, PBYTE*);
	NET_API_STATUS NetRemoteComputerSupports(LPCWSTR, DWORD, PDWORD);
	NET_API_STATUS RxRemoteApi(DWORD, LPCWSTR, LPDESC, LPDESC, LPDESC,
	  LPDESC, LPDESC, LPDESC, LPDESC, DWORD, ...);
}
