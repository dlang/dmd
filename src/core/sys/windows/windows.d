/***********************************************************************\
*                               windows.d                               *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*             Translated from MinGW API for MS-Windows 4.0              *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.windows;

/*
	windows.h - main header file for the Win32 API

	Written by Anders Norlander <anorland@hem2.passagen.se>

	This file is part of a free library for the Win32 API.

	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

*/

public import win32.w32api;
public import win32.core;

public import win32.cderr;
public import win32.dde;
public import win32.ddeml;
public import win32.dlgs;
public import win32.imm;
public import win32.lzexpand;
public import win32.mmsystem;
public import win32.nb30;
public import win32.winsvc;

public import win32.rpc;
public import win32.shellapi;
public import win32.winperf;
public import win32.commdlg;
public import win32.winspool;
public import win32.ole2;

// Select correct version of winsock.  Importing the incorrect
// module will cause a static assert to prevent problems later on.
version (Win32_Winsock1) {
	public import win32.winsock;
} else {
	public import win32.winsock2;
	public import win32.ws2tcpip;
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
