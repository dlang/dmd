/***********************************************************************\
*                               isguids.d                               *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*             Translated from MinGW API for MS-Windows 3.10             *
*                           by Stewart Gordon                           *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module core.sys.windows.isguids;

private import core.sys.windows.basetyps;

extern (C) extern const GUID
	CLSID_InternetShortcut,
	IID_IUniformResourceLocator;
