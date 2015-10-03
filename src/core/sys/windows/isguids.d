/**
 * Windows API header module
 *
 * Translated from MinGW API for MS-Windows 3.10
 *
 * Authors: Stewart Gordon
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_isguids.d)
 */
module core.sys.windows.isguids;

private import core.sys.windows.basetyps;

extern (C) extern const GUID
	CLSID_InternetShortcut,
	IID_IUniformResourceLocator;
