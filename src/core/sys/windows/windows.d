/**
 * Windows API header module
 *
 * Translated from MinGW API for MS-Windows 4.0
 *
 * License: Placed into public domain
 * Source: $(DRUNTIMESRC src/core/sys/windows/_windows.d)
 */
module core.sys.windows.windows;

/*
	windows.h - main header file for the Win32 API

	Written by Anders Norlander <anorland@hem2.passagen.se>

	This file is part of a free library for the Win32 API.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

*/

public import core.sys.windows.w32api;
public import core.sys.windows.core;

public import core.sys.windows.cderr;
public import core.sys.windows.dde;
public import core.sys.windows.ddeml;
public import core.sys.windows.dlgs;
public import core.sys.windows.imm;
public import core.sys.windows.lzexpand;
public import core.sys.windows.mmsystem;
public import core.sys.windows.nb30;
public import core.sys.windows.winsvc;

public import core.sys.windows.rpc;
public import core.sys.windows.shellapi;
public import core.sys.windows.winperf;
public import core.sys.windows.commdlg;
public import core.sys.windows.winspool;
public import core.sys.windows.ole2;

// Select correct version of winsock.  Importing the incorrect
// module will cause a static assert to prevent problems later on.
version (Win32_Winsock1) {
	public import core.sys.windows.winsock;
} else {
	public import core.sys.windows.winsock2;
	public import core.sys.windows.ws2tcpip;
}

/+
#if (_WIN32_WINNT >= 0x400)
#include <winsock2.h>
/*
 * MS likes to include mswsock.h here as well,
 * but that can cause undefined symbols if
 * winsock2.h is included before windows.h
 */
#else
#include <winsock.h>
#endif /*  (_WIN32_WINNT >= 0x400) */
+/
