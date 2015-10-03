/***********************************************************************\
*                                core.d                                 *
*                                                                       *
*                    Helper module for the Windows API                  *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/
module win32.core;

/**
 The core Windows API functions.

 Importing this file is equivalent to the C code:
 ---
 #define WIN32_LEAN_AND_MEAN
 #include "windows.h"
 ---

*/

public import win32.windef;
public import win32.winnt;
public import win32.wincon;
public import win32.winbase;
public import win32.wingdi;
public import win32.winuser;
public import win32.winnls;
public import win32.winver;
public import win32.winnetwk;
public import win32.winsvc;
