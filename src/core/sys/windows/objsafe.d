/***********************************************************************\
*                               objsafe.d                               *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                           by Stewart Gordon                           *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module core.sys.windows.objsafe;

private import core.sys.windows.basetyps, core.sys.windows.unknwn, core.sys.windows.windef;

enum {
	INTERFACESAFE_FOR_UNTRUSTED_CALLER = 1,
	INTERFACESAFE_FOR_UNTRUSTED_DATA
}

interface IObjectSafety : IUnknown {
	HRESULT GetInterfaceSafetyOptions(REFIID, DWORD*, DWORD*);
	HRESULT SetInterfaceSafetyOptions(REFIID, DWORD, DWORD);
}
