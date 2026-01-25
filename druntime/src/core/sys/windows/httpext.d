/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_httpext.d)
 */
module core.sys.windows.httpext;
version (Windows):

/* Comment from MinGW
       httpext.h - Header for ISAPI extensions.

       This file is part of a free library for the Win32 API.

       This library is distributed in the hope that it will be useful,
       but WITHOUT ANY WARRANTY; without even the implied warranty of
       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
*/

import core.sys.windows.basetsd /+: HANDLE+/;
import core.sys.windows.windef /+: BOOL, CHAR, DWORD, LPBYTE, LPDWORD+/;
import core.sys.windows.winnt /+: LPCSTR, LPSTR, LPVOID, PVOID, VOID+/;

enum {
    HSE_VERSION_MAJOR               = 2,
    HSE_VERSION_MINOR               = 0,
    HSE_LOG_BUFFER_LEN              = 80,
    HSE_MAX_EXT_DLL_NAME_LEN        = 256,
    HSE_STATUS_SUCCESS              = 1,
    HSE_STATUS_SUCCESS_AND_KEEP_CONN,
    HSE_STATUS_PENDING,
    HSE_STATUS_ERROR,
    HSE_REQ_BASE                    = 0,
    HSE_REQ_SEND_URL_REDIRECT_RESP,
    HSE_REQ_SEND_URL,
    HSE_REQ_SEND_RESPONSE_HEADER,
    HSE_REQ_DONE_WITH_SESSION,
    HSE_REQ_SEND_RESPONSE_HEADER_EX = 1016,
    HSE_REQ_END_RESERVED            = 1000,
    HSE_TERM_ADVISORY_UNLOAD        = 0x00000001,
    HSE_TERM_MUST_UNLOAD,
    HSE_IO_SYNC                     = 0x00000001,
    HSE_IO_ASYNC,
    HSE_IO_DISCONNECT_AFTER_SEND    = 0x00000004,
    HSE_IO_SEND_HEADERS             = 0x00000008
}

alias HCONN = HANDLE;

struct HSE_VERSION_INFO {
    DWORD dwExtensionVersion;
    CHAR[HSE_MAX_EXT_DLL_NAME_LEN] lpszExtensionDesc = 0;
}
alias LPHSE_VERSION_INFO = HSE_VERSION_INFO*;

struct EXTENSION_CONTROL_BLOCK {
    DWORD  cbSize = EXTENSION_CONTROL_BLOCK.sizeof;
    DWORD  dwVersion;
    HCONN  ConnID;
    DWORD  dwHttpStatusCode;
    CHAR[HSE_LOG_BUFFER_LEN] lpszLogData = 0;
    LPSTR  lpszMethod;
    LPSTR  lpszQueryString;
    LPSTR  lpszPathInfo;
    LPSTR  lpszPathTranslated;
    DWORD  cbTotalBytes;
    DWORD  cbAvailable;
    LPBYTE lpbData;
    LPSTR  lpszContentType;
    extern (Windows) {
        BOOL function(HCONN, LPSTR, LPVOID, LPDWORD) GetServerVariable;
        BOOL function(HCONN, LPVOID, LPDWORD, DWORD) WriteClient;
        BOOL function(HCONN, LPVOID, LPDWORD) ReadClient;
        BOOL function(HCONN, DWORD, LPVOID, LPDWORD, LPDWORD) ServerSupportFunction;
    }
}
alias LPEXTENSION_CONTROL_BLOCK = EXTENSION_CONTROL_BLOCK*;

extern (Windows) {
    alias PFN_GETEXTENSIONVERSION = BOOL function(HSE_VERSION_INFO*);
    alias PFN_HTTPEXTENSIONPROC = DWORD function(EXTENSION_CONTROL_BLOCK*);
    alias PFN_TERMINATEEXTENSION = BOOL function(DWORD);
    alias PFN_HSE_IO_COMPLETION = VOID function(EXTENSION_CONTROL_BLOCK*, PVOID, DWORD, DWORD);
}

struct HSE_TF_INFO {
    PFN_HSE_IO_COMPLETION pfnHseIO;
    PVOID  pContext;
    HANDLE hFile;
    LPCSTR pszStatusCode;
    DWORD  BytesToWrite;
    DWORD  Offset;
    PVOID  pHead;
    DWORD  HeadLength;
    PVOID  pTail;
    DWORD  TailLength;
    DWORD  dwFlags;
}
alias LPHSE_TF_INFO = HSE_TF_INFO*;

struct HSE_SEND_HEADER_EX_INFO {
    LPCSTR pszStatus;
    LPCSTR pszHeader;
    DWORD  cchStatus;
    DWORD  cchHeader;
    BOOL   fKeepConn;
}
alias LPHSE_SEND_HEADER_EX_INF = HSE_SEND_HEADER_EX_INFO*;

extern (Windows) nothrow @nogc {
    BOOL GetExtensionVersion(HSE_VERSION_INFO*);
    DWORD HttpExtensionProc(EXTENSION_CONTROL_BLOCK*);
    BOOL TerminateExtension(DWORD);
}
