/***********************************************************************\
*                               servprov.d                              *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*             Translated from MinGW API for MS-Windows 3.10             *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.servprov;

private import win32.basetyps, win32.unknwn, win32.windef, win32.wtypes;

interface IServiceProvider : IUnknown {
	HRESULT QueryService(REFGUID, REFIID, void**);
}
