/**
 * Windows API header module
 *
 * Translated from MinGW API for MS-Windows 3.10
 *
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_basetyps.d)
 */
module core.sys.windows.basetyps;
version (Windows):

private import core.sys.windows.windef, core.sys.windows.basetsd;

align(1) struct GUID {  // size is 16
    align(1):
    DWORD   Data1;
    WORD    Data2;
    WORD    Data3;
    BYTE[8] Data4;
}
alias GUID UUID, /*IID, CLSID, */FMTID, uuid_t;
alias IID = const(GUID);
alias CLSID = const(GUID);

alias GUID* LPGUID, LPCLSID, LPIID;
alias const(GUID)* LPCGUID, REFGUID, REFIID, REFCLSID, REFFMTID;
alias uint error_status_t, PROPID;
