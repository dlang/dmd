/**
 * Windows API header module
 *
 * Translated from MinGW API for MS-Windows 3.10
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_basetyps.d)
 */
module core.sys.windows.basetyps;
version (Windows):

import core.sys.windows.windef, core.sys.windows.basetsd;

align(1) struct GUID {  // size is 16
    align(1):
    DWORD   Data1;
    WORD    Data2;
    WORD    Data3;
    BYTE[8] Data4;
}
alias UUID = GUID, /*IID, CLSID, */FMTID = GUID, uuid_t = GUID;
alias IID = const(GUID);
alias CLSID = const(GUID);

alias LPGUID = GUID*, LPCLSID = GUID*, LPIID = GUID*;
alias LPCGUID = const(GUID)*, REFGUID = const(GUID)*, REFIID = const(GUID)*, REFCLSID = const(GUID)*, REFFMTID = const(GUID)*;
alias error_status_t = uint, PROPID = uint;
