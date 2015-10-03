/***********************************************************************\
*                               basetyps.d                              *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*             Translated from MinGW API for MS-Windows 3.10             *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.basetyps;

private import win32.windef, win32.basetsd;

align(1) struct GUID {  // size is 16
	DWORD   Data1;
	WORD    Data2;
	WORD    Data3;
	BYTE[8] Data4;
}
alias GUID UUID, IID, CLSID, FMTID, uuid_t;
alias GUID* LPGUID, LPCLSID, LPIID;
alias const(GUID)* REFGUID, REFIID, REFCLSID, REFFMTID;

alias uint error_status_t, PROPID;
