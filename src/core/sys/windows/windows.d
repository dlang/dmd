/**
 *  Windows is a registered trademark of Microsoft Corporation in the United
 *  States and other countries.
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Alex Rønne Petersen
 * Source:    $(DRUNTIMESRC core/sys/windows/_windows.d)
 */

module core.sys.windows.windows;

version (Windows):
extern (Windows):
nothrow:
//@nogc:

    alias uint ULONG;
    alias ULONG *PULONG;
    alias ushort USHORT;
    alias USHORT *PUSHORT;
    alias ubyte UCHAR;
    alias UCHAR *PUCHAR;
    alias char *PSZ;

    alias void VOID;
    alias char CHAR;
    alias short SHORT;
    alias int LONG;

    alias long  LONGLONG;
    alias ulong ULONGLONG;

    alias CHAR*         LPCH,  LPSTR,  PCH,  PSTR;
    alias const(CHAR)*  LPCCH, LPCSTR, PCCH, PCSTR;

    alias wchar WCHAR;
    alias WCHAR*        LPWCH,  LPWSTR,  PWCH,  PWSTR;
    alias const(WCHAR)* LPCWCH, LPCWSTR, PCWCH, PCWSTR;

    alias CHAR*         LPTCH,  LPTSTR,  PTCH,  PTSTR;
    alias const(CHAR)*  LPCTCH, LPCTSTR, PCTCH, PCTSTR;

    alias uint DWORD;
    alias ulong DWORD64;
    alias int BOOL;
    alias ubyte BYTE;
    alias ushort WORD;
    alias float FLOAT;
    alias FLOAT* PFLOAT;
    alias BOOL*  LPBOOL,  PBOOL;
    alias BYTE*  LPBYTE,  PBYTE;
    alias int*   LPINT,   PINT;
    alias WORD*  LPWORD,  PWORD;
    alias int*   LPLONG;
    alias DWORD* LPDWORD, PDWORD;
    alias void*  LPVOID;
    alias const(void)* LPCVOID;

    alias int INT;
    alias uint UINT;
    alias uint* PUINT;

    alias size_t SIZE_T;

// ULONG_PTR must be able to store a pointer as an integral type
version (Win64)
{
    alias  long INT_PTR;
    alias ulong UINT_PTR;
    alias  long LONG_PTR;
    alias ulong ULONG_PTR;
    alias  long * PINT_PTR;
    alias ulong * PUINT_PTR;
    alias  long * PLONG_PTR;
    alias ulong * PULONG_PTR;
}
else version (Win32)
{
    alias  int INT_PTR;
    alias uint UINT_PTR;
    alias  int LONG_PTR;
    alias uint ULONG_PTR;
    alias  int * PINT_PTR;
    alias uint * PUINT_PTR;
    alias  int * PLONG_PTR;
    alias uint * PULONG_PTR;
}

    alias ULONG_PTR DWORD_PTR;

    alias void *HANDLE;
    alias void *PVOID;
    alias HANDLE HGLOBAL;
    alias HANDLE HLOCAL;
    alias LONG HRESULT;
    alias LONG SCODE;
    alias HANDLE HINSTANCE;
    alias HINSTANCE HMODULE;
    alias HANDLE HWND;
    alias HANDLE* PHANDLE;

    alias HANDLE HGDIOBJ;
    alias HANDLE HACCEL;
    alias HANDLE HBITMAP;
    alias HANDLE HBRUSH;
    alias HANDLE HCOLORSPACE;
    alias HANDLE HDC;
    alias HANDLE HGLRC;
    alias HANDLE HDESK;
    alias HANDLE HENHMETAFILE;
    alias HANDLE HFONT;
    alias HANDLE HICON;
    alias HANDLE HMENU;
    alias HANDLE HMETAFILE;
    alias HANDLE HPALETTE;
    alias HANDLE HPEN;
    alias HANDLE HRGN;
    alias HANDLE HRSRC;
    alias HANDLE HSTR;
    alias HANDLE HTASK;
    alias HANDLE HWINSTA;
    alias HANDLE HKL;
    alias HICON HCURSOR;

    alias HANDLE HKEY;
    alias HKEY *PHKEY;
    alias DWORD ACCESS_MASK;
    alias ACCESS_MASK *PACCESS_MASK;
    alias ACCESS_MASK REGSAM;

    version (Win64)
        alias INT_PTR function() FARPROC;
    else version (Win32)
        alias int function() FARPROC;

    alias UINT_PTR WPARAM;
    alias LONG_PTR LPARAM;
    alias LONG_PTR LRESULT;

    alias DWORD   COLORREF;
    alias DWORD   *LPCOLORREF;
    alias WORD    ATOM;

version (all)
{
    // Properly prototyped versions
    alias INT_PTR function(HWND, UINT, WPARAM, LPARAM) DLGPROC;
    alias VOID function(HWND, UINT, UINT_PTR, DWORD) TIMERPROC;
    alias BOOL function(HDC, LPARAM, int) GRAYSTRINGPROC;
    alias BOOL function(HWND, LPARAM) WNDENUMPROC;
    alias LRESULT function(int code, WPARAM wParam, LPARAM lParam) HOOKPROC;
    alias VOID function(HWND, UINT, ULONG_PTR, LRESULT) SENDASYNCPROC;
    alias BOOL function(HWND, LPCSTR, HANDLE) PROPENUMPROCA;
    alias BOOL function(HWND, LPCWSTR, HANDLE) PROPENUMPROCW;
    alias BOOL function(HWND, LPSTR, HANDLE, ULONG_PTR) PROPENUMPROCEXA;
    alias BOOL function(HWND, LPWSTR, HANDLE, ULONG_PTR) PROPENUMPROCEXW;
    alias int function(LPSTR lpch, int ichCurrent, int cch, int code)
       EDITWORDBREAKPROCA;
    alias int function(LPWSTR lpch, int ichCurrent, int cch, int code)
       EDITWORDBREAKPROCW;
    alias BOOL function(HDC hdc, LPARAM lData, WPARAM wData, int cx, int cy)
       DRAWSTATEPROC;
}
else
{
    alias FARPROC DLGPROC;
    alias FARPROC TIMERPROC;
    alias FARPROC GRAYSTRINGPROC;
    alias FARPROC WNDENUMPROC;
    alias FARPROC HOOKPROC;
    alias FARPROC SENDASYNCPROC;
    alias FARPROC EDITWORDBREAKPROCA;
    alias FARPROC EDITWORDBREAKPROCW;
    alias FARPROC PROPENUMPROCA;
    alias FARPROC PROPENUMPROCW;
    alias FARPROC PROPENUMPROCEXA;
    alias FARPROC PROPENUMPROCEXW;
    alias FARPROC DRAWSTATEPROC;
}

extern (D) pure @nogc
{
WORD HIWORD(long x) { return cast(WORD)((x >> 16) & 0xFFFF); }
WORD LOWORD(long x) { return cast(WORD)x; }
bool FAILED(int status) { return status < 0; }
bool SUCCEEDED(int Status) { return Status >= 0; }
}

enum : int
{
    FALSE = 0,
    TRUE = 1,
}

enum : uint
{
    MAX_PATH = 260,
    HINSTANCE_ERROR = 32,
}

enum
{
    ERROR_SUCCESS =                    0,
    ERROR_INVALID_FUNCTION =           1,
    ERROR_FILE_NOT_FOUND =             2,
    ERROR_PATH_NOT_FOUND =             3,
    ERROR_TOO_MANY_OPEN_FILES =        4,
    ERROR_ACCESS_DENIED =              5,
    ERROR_INVALID_HANDLE =             6,
    ERROR_NO_MORE_FILES =              18,
    ERROR_LOCK_VIOLATION =             33,
    ERROR_INSUFFICIENT_BUFFER =        122,
    ERROR_ALREADY_EXISTS =             183,
    ERROR_MORE_DATA =          234,
    ERROR_NO_MORE_ITEMS =          259,
    ERROR_IO_PENDING =                 997,
}

enum
{
    DLL_PROCESS_ATTACH = 1,
    DLL_THREAD_ATTACH =  2,
    DLL_THREAD_DETACH =  3,
    DLL_PROCESS_DETACH = 0,
}

enum
{
    FILE_BEGIN           = 0,
    FILE_CURRENT         = 1,
    FILE_END             = 2,
}

enum : uint
{
    DELETE =                           0x00010000,
    READ_CONTROL =                     0x00020000,
    WRITE_DAC =                        0x00040000,
    WRITE_OWNER =                      0x00080000,
    SYNCHRONIZE =                      0x00100000,

    STANDARD_RIGHTS_REQUIRED =         0x000F0000,
    STANDARD_RIGHTS_READ =             READ_CONTROL,
    STANDARD_RIGHTS_WRITE =            READ_CONTROL,
    STANDARD_RIGHTS_EXECUTE =          READ_CONTROL,
    STANDARD_RIGHTS_ALL =              0x001F0000,
    SPECIFIC_RIGHTS_ALL =              0x0000FFFF,
    ACCESS_SYSTEM_SECURITY =           0x01000000,
    MAXIMUM_ALLOWED =                  0x02000000,

    GENERIC_READ                     = 0x80000000,
    GENERIC_WRITE                    = 0x40000000,
    GENERIC_EXECUTE                  = 0x20000000,
    GENERIC_ALL                      = 0x10000000,
}

enum
{
    FILE_SHARE_READ                 = 0x00000001,
    FILE_SHARE_WRITE                = 0x00000002,
    FILE_SHARE_DELETE               = 0x00000004,
    FILE_ATTRIBUTE_READONLY         = 0x00000001,
    FILE_ATTRIBUTE_HIDDEN           = 0x00000002,
    FILE_ATTRIBUTE_SYSTEM           = 0x00000004,
    FILE_ATTRIBUTE_DIRECTORY        = 0x00000010,
    FILE_ATTRIBUTE_ARCHIVE          = 0x00000020,
    FILE_ATTRIBUTE_NORMAL           = 0x00000080,
    FILE_ATTRIBUTE_TEMPORARY        = 0x00000100,
    FILE_ATTRIBUTE_COMPRESSED       = 0x00000800,
    FILE_ATTRIBUTE_OFFLINE          = 0x00001000,
    FILE_NOTIFY_CHANGE_FILE_NAME    = 0x00000001,
    FILE_NOTIFY_CHANGE_DIR_NAME     = 0x00000002,
    FILE_NOTIFY_CHANGE_ATTRIBUTES   = 0x00000004,
    FILE_NOTIFY_CHANGE_SIZE         = 0x00000008,
    FILE_NOTIFY_CHANGE_LAST_WRITE   = 0x00000010,
    FILE_NOTIFY_CHANGE_LAST_ACCESS  = 0x00000020,
    FILE_NOTIFY_CHANGE_CREATION     = 0x00000040,
    FILE_NOTIFY_CHANGE_SECURITY     = 0x00000100,
    FILE_ACTION_ADDED               = 0x00000001,
    FILE_ACTION_REMOVED             = 0x00000002,
    FILE_ACTION_MODIFIED            = 0x00000003,
    FILE_ACTION_RENAMED_OLD_NAME    = 0x00000004,
    FILE_ACTION_RENAMED_NEW_NAME    = 0x00000005,
    FILE_CASE_SENSITIVE_SEARCH      = 0x00000001,
    FILE_CASE_PRESERVED_NAMES       = 0x00000002,
    FILE_UNICODE_ON_DISK            = 0x00000004,
    FILE_PERSISTENT_ACLS            = 0x00000008,
    FILE_FILE_COMPRESSION           = 0x00000010,
    FILE_VOLUME_IS_COMPRESSED       = 0x00008000,
}

enum : DWORD
{
    INVALID_FILE_ATTRIBUTES = cast(DWORD)-1,
}

enum : DWORD
{
    MAILSLOT_NO_MESSAGE = cast(DWORD)-1,
    MAILSLOT_WAIT_FOREVER = cast(DWORD)-1,
}

enum : uint
{
    FILE_FLAG_WRITE_THROUGH         = 0x80000000,
    FILE_FLAG_OVERLAPPED            = 0x40000000,
    FILE_FLAG_NO_BUFFERING          = 0x20000000,
    FILE_FLAG_RANDOM_ACCESS         = 0x10000000,
    FILE_FLAG_SEQUENTIAL_SCAN       = 0x08000000,
    FILE_FLAG_DELETE_ON_CLOSE       = 0x04000000,
    FILE_FLAG_BACKUP_SEMANTICS      = 0x02000000,
    FILE_FLAG_POSIX_SEMANTICS       = 0x01000000,
}

enum
{
    CREATE_NEW          = 1,
    CREATE_ALWAYS       = 2,
    OPEN_EXISTING       = 3,
    OPEN_ALWAYS         = 4,
    TRUNCATE_EXISTING   = 5,
}


enum
{
    HANDLE INVALID_HANDLE_VALUE     = cast(HANDLE)-1,
    DWORD INVALID_SET_FILE_POINTER  = cast(DWORD)-1,
    DWORD INVALID_FILE_SIZE         = cast(DWORD)0xFFFFFFFF,
}

union LARGE_INTEGER
{
    struct
    {
        uint LowPart;
        int  HighPart;
    }
    long QuadPart;
}
alias LARGE_INTEGER* PLARGE_INTEGER;

union ULARGE_INTEGER
{
    struct
    {
        uint LowPart;
        uint HighPart;
    }
    ulong QuadPart;
}
alias ULARGE_INTEGER* PULARGE_INTEGER;

struct OVERLAPPED {
    ULONG_PTR Internal;
    ULONG_PTR InternalHigh;
    union {
        struct {
            DWORD Offset;
            DWORD OffsetHigh;
        }
        void* Pointer;
    }
    HANDLE hEvent;
}
alias OVERLAPPED* LPOVERLAPPED;

struct SECURITY_ATTRIBUTES {
    DWORD nLength;
    void *lpSecurityDescriptor;
    BOOL bInheritHandle;
}

alias SECURITY_ATTRIBUTES* PSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES;

struct FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
}
alias FILETIME* PFILETIME, LPFILETIME;

struct WIN32_FIND_DATA {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD dwReserved0;
    DWORD dwReserved1;
    char[MAX_PATH] cFileName;
    char[14] cAlternateFileName;
}

struct WIN32_FIND_DATAW {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD dwReserved0;
    DWORD dwReserved1;
    wchar[260] cFileName;
    wchar[14]  cAlternateFileName;
}

// Critical Section

struct _LIST_ENTRY
{
    _LIST_ENTRY *Flink;
    _LIST_ENTRY *Blink;
}
alias _LIST_ENTRY LIST_ENTRY;

struct _RTL_CRITICAL_SECTION_DEBUG
{
    WORD   Type;
    WORD   CreatorBackTraceIndex;
    _RTL_CRITICAL_SECTION *CriticalSection;
    LIST_ENTRY ProcessLocksList;
    DWORD EntryCount;
    DWORD ContentionCount;
    DWORD[2] Spare;
}
alias _RTL_CRITICAL_SECTION_DEBUG RTL_CRITICAL_SECTION_DEBUG;

struct _RTL_CRITICAL_SECTION
{
    RTL_CRITICAL_SECTION_DEBUG * DebugInfo;

    //
    //  The following three fields control entering and exiting the critical
    //  section for the resource
    //

    LONG LockCount;
    LONG RecursionCount;
    HANDLE OwningThread;        // from the thread's ClientId->UniqueThread
    HANDLE LockSemaphore;
    ULONG_PTR SpinCount;        // force size on 64-bit systems when packed
}
alias _RTL_CRITICAL_SECTION CRITICAL_SECTION;


enum
{
    STD_INPUT_HANDLE =    cast(DWORD)-10,
    STD_OUTPUT_HANDLE =   cast(DWORD)-11,
    STD_ERROR_HANDLE =    cast(DWORD)-12,
}

enum GET_FILEEX_INFO_LEVELS
{
    GetFileExInfoStandard,
    GetFileExMaxInfoLevel
}

struct WIN32_FILE_ATTRIBUTE_DATA
{
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
}
alias WIN32_FILE_ATTRIBUTE_DATA* LPWIN32_FILE_ATTRIBUTE_DATA;

export @nogc
{
BOOL SetCurrentDirectoryA(LPCSTR lpPathName);
BOOL SetCurrentDirectoryW(LPCWSTR lpPathName);
UINT GetSystemDirectoryA(LPSTR lpBuffer, UINT uSize);
UINT GetSystemDirectoryW(LPWSTR lpBuffer, UINT uSize);
DWORD GetCurrentDirectoryA(DWORD nBufferLength, LPSTR lpBuffer);
DWORD GetCurrentDirectoryW(DWORD nBufferLength, LPWSTR lpBuffer);
BOOL CreateDirectoryA(LPCSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL CreateDirectoryW(LPCWSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL CreateDirectoryExA(LPCSTR lpTemplateDirectory, LPCSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL CreateDirectoryExW(LPCWSTR lpTemplateDirectory, LPCWSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL RemoveDirectoryA(LPCSTR lpPathName);
BOOL RemoveDirectoryW(LPCWSTR lpPathName);

BOOL   CloseHandle(HANDLE hObject) @trusted;

HANDLE CreateFileA(in char* lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
    SECURITY_ATTRIBUTES *lpSecurityAttributes, DWORD dwCreationDisposition,
    DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
HANDLE CreateFileW(LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
    SECURITY_ATTRIBUTES *lpSecurityAttributes, DWORD dwCreationDisposition,
    DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);

BOOL   DeleteFileA(in char *lpFileName);
BOOL   DeleteFileW(LPCWSTR lpFileName);

BOOL   FindClose(HANDLE hFindFile);
HANDLE FindFirstFileA(in char *lpFileName, WIN32_FIND_DATA* lpFindFileData);
HANDLE FindFirstFileW(in LPCWSTR lpFileName, WIN32_FIND_DATAW* lpFindFileData);
BOOL   FindNextFileA(HANDLE hFindFile, WIN32_FIND_DATA* lpFindFileData);
BOOL   FindNextFileW(HANDLE hFindFile, WIN32_FIND_DATAW* lpFindFileData);
BOOL   GetExitCodeThread(HANDLE hThread, DWORD *lpExitCode);
BOOL   GetExitCodeProcess(HANDLE hProcess, DWORD *lpExitCode);
DWORD  GetLastError() @trusted;
DWORD  GetFileAttributesA(in char *lpFileName);
DWORD  GetFileAttributesW(in wchar *lpFileName);
BOOL   GetFileAttributesExA(LPCSTR, GET_FILEEX_INFO_LEVELS, PVOID);
BOOL   GetFileAttributesExW(LPCWSTR, GET_FILEEX_INFO_LEVELS, PVOID);
DWORD  GetFileSize(HANDLE hFile, DWORD *lpFileSizeHigh);
BOOL   CopyFileA(LPCSTR lpExistingFileName, LPCSTR lpNewFileName, BOOL bFailIfExists);
BOOL   CopyFileW(LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, BOOL bFailIfExists);
BOOL   MoveFileA(in char *from, in char *to);
BOOL   MoveFileW(LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName);
BOOL   ReadFile(HANDLE hFile, void *lpBuffer, DWORD nNumberOfBytesToRead,
    DWORD *lpNumberOfBytesRead, OVERLAPPED *lpOverlapped);
BOOL   SetFileAttributesA(in LPCSTR lpFileName, DWORD dwFileAttributes);
BOOL   SetFileAttributesW(in LPCWSTR lpFileName, DWORD dwFileAttributes);
DWORD  SetFilePointer(HANDLE hFile, LONG lDistanceToMove,
    LONG *lpDistanceToMoveHigh, DWORD dwMoveMethod);
BOOL   WriteFile(HANDLE hFile, in void *lpBuffer, DWORD nNumberOfBytesToWrite,
    DWORD *lpNumberOfBytesWritten, OVERLAPPED *lpOverlapped);
DWORD  GetModuleFileNameA(HMODULE hModule, LPSTR lpFilename, DWORD nSize);
DWORD  GetModuleFileNameW(HMODULE hModule, LPWSTR lpFilename, DWORD nSize);
HANDLE GetStdHandle(DWORD nStdHandle);
BOOL   SetStdHandle(DWORD nStdHandle, HANDLE hHandle);
HWND GetConsoleWindow();
}

struct MEMORYSTATUS {
    DWORD dwLength;
    DWORD dwMemoryLoad;
    DWORD dwTotalPhys;
    DWORD dwAvailPhys;
    DWORD dwTotalPageFile;
    DWORD dwAvailPageFile;
    DWORD dwTotalVirtual;
    DWORD dwAvailVirtual;
};
alias MEMORYSTATUS *LPMEMORYSTATUS;

@nogc
{
HMODULE LoadLibraryA(LPCSTR lpLibFileName);
HMODULE LoadLibraryW(LPCWSTR lpLibFileName);
FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);
DWORD GetVersion();
BOOL FreeLibrary(HMODULE hLibModule);
void FreeLibraryAndExitThread(HMODULE hLibModule, DWORD dwExitCode);
BOOL DisableThreadLibraryCalls(HMODULE hLibModule);
}

//
// Registry Specific Access Rights.
//

enum
{
    KEY_QUERY_VALUE =         0x0001,
    KEY_SET_VALUE =           0x0002,
    KEY_CREATE_SUB_KEY =      0x0004,
    KEY_ENUMERATE_SUB_KEYS =  0x0008,
    KEY_NOTIFY =              0x0010,
    KEY_CREATE_LINK =         0x0020,

    KEY_READ =       cast(int)((STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY)   & ~SYNCHRONIZE),
    KEY_WRITE =      cast(int)((STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY) & ~SYNCHRONIZE),
    KEY_EXECUTE =    cast(int)(KEY_READ & ~SYNCHRONIZE),
    KEY_ALL_ACCESS = cast(int)((STANDARD_RIGHTS_ALL | KEY_QUERY_VALUE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY | KEY_CREATE_LINK) & ~SYNCHRONIZE),
}

//
// Key creation/open disposition
//

enum : int
{
    REG_CREATED_NEW_KEY =         0x00000001,   // New Registry Key created
    REG_OPENED_EXISTING_KEY =     0x00000002,   // Existing Key opened
}

//
//
// Predefined Value Types.
//
enum
{
    REG_NONE =                    0,   // No value type
    REG_SZ =                      1,   // Unicode nul terminated string
    REG_EXPAND_SZ =               2,   // Unicode nul terminated string
                                            // (with environment variable references)
    REG_BINARY =                  3,   // Free form binary
    REG_DWORD =                   4,   // 32-bit number
    REG_DWORD_LITTLE_ENDIAN =     4,   // 32-bit number (same as REG_DWORD)
    REG_DWORD_BIG_ENDIAN =        5,   // 32-bit number
    REG_LINK =                    6,   // Symbolic Link (unicode)
    REG_MULTI_SZ =                7,   // Multiple Unicode strings
    REG_RESOURCE_LIST =           8,   // Resource list in the resource map
    REG_FULL_RESOURCE_DESCRIPTOR = 9,  // Resource list in the hardware description
    REG_RESOURCE_REQUIREMENTS_LIST = 10,
    REG_QWORD =         11,
    REG_QWORD_LITTLE_ENDIAN =   11,
}

/*
 * MessageBox() Flags
 */
enum
{
    MB_OK =                       0x00000000,
    MB_OKCANCEL =                 0x00000001,
    MB_ABORTRETRYIGNORE =         0x00000002,
    MB_YESNOCANCEL =              0x00000003,
    MB_YESNO =                    0x00000004,
    MB_RETRYCANCEL =              0x00000005,


    MB_ICONHAND =                 0x00000010,
    MB_ICONQUESTION =             0x00000020,
    MB_ICONEXCLAMATION =          0x00000030,
    MB_ICONASTERISK =             0x00000040,


    MB_USERICON =                 0x00000080,
    MB_ICONWARNING =              MB_ICONEXCLAMATION,
    MB_ICONERROR =                MB_ICONHAND,


    MB_ICONINFORMATION =          MB_ICONASTERISK,
    MB_ICONSTOP =                 MB_ICONHAND,

    MB_DEFBUTTON1 =               0x00000000,
    MB_DEFBUTTON2 =               0x00000100,
    MB_DEFBUTTON3 =               0x00000200,

    MB_DEFBUTTON4 =               0x00000300,


    MB_APPLMODAL =                0x00000000,
    MB_SYSTEMMODAL =              0x00001000,
    MB_TASKMODAL =                0x00002000,

    MB_HELP =                     0x00004000, // Help Button


    MB_NOFOCUS =                  0x00008000,
    MB_SETFOREGROUND =            0x00010000,
    MB_DEFAULT_DESKTOP_ONLY =     0x00020000,


    MB_TOPMOST =                  0x00040000,
    MB_RIGHT =                    0x00080000,
    MB_RTLREADING =               0x00100000,


    MB_TYPEMASK =                 0x0000000F,
    MB_ICONMASK =                 0x000000F0,
    MB_DEFMASK =                  0x00000F00,
    MB_MODEMASK =                 0x00003000,
    MB_MISCMASK =                 0x0000C000,
}

@nogc
{
int MessageBoxA(HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType);
int MessageBoxW(HWND hWnd, LPCWSTR lpText, LPCWSTR lpCaption, UINT uType);
int MessageBoxExA(HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType, WORD wLanguageId);
int MessageBoxExW(HWND hWnd, LPCWSTR lpText, LPCWSTR lpCaption, UINT uType, WORD wLanguageId);
}

enum : HKEY
{
    HKEY_CLASSES_ROOT =           cast(HKEY)(0x80000000),
    HKEY_CURRENT_USER =           cast(HKEY)(0x80000001),
    HKEY_LOCAL_MACHINE =          cast(HKEY)(0x80000002),
    HKEY_USERS =                  cast(HKEY)(0x80000003),
    HKEY_PERFORMANCE_DATA =       cast(HKEY)(0x80000004),
    HKEY_PERFORMANCE_TEXT =       cast(HKEY)(0x80000050),
    HKEY_PERFORMANCE_NLSTEXT =    cast(HKEY)(0x80000060),
    HKEY_CURRENT_CONFIG =         cast(HKEY)(0x80000005),
    HKEY_DYN_DATA =               cast(HKEY)(0x80000006),
}


enum
{
    REG_OPTION_RESERVED =         (0x00000000),   // Parameter is reserved

    REG_OPTION_NON_VOLATILE =     (0x00000000),   // Key is preserved
                                                    // when system is rebooted

    REG_OPTION_VOLATILE =         (0x00000001),   // Key is not preserved
                                                    // when system is rebooted

    REG_OPTION_CREATE_LINK =      (0x00000002),   // Created key is a
                                                    // symbolic link

    REG_OPTION_BACKUP_RESTORE =   (0x00000004),   // open for backup or restore
                                                    // special access rules
                                                    // privilege required

    REG_OPTION_OPEN_LINK =        (0x00000008),   // Open symbolic link

    REG_LEGAL_OPTION = (REG_OPTION_RESERVED | REG_OPTION_NON_VOLATILE | REG_OPTION_VOLATILE | REG_OPTION_CREATE_LINK | REG_OPTION_BACKUP_RESTORE | REG_OPTION_OPEN_LINK),
}

@nogc
{
export LONG RegDeleteKeyA(in HKEY hKey, LPCSTR lpSubKey);
export LONG RegDeleteKeyW(in HKEY hKey, LPCWSTR lpSubKey);
export LONG RegDeleteValueA(in HKEY hKey, LPCSTR lpValueName);
export LONG RegDeleteValueW(in HKEY hKey, LPCWSTR lpValueName);

export LONG  RegEnumKeyExA(in HKEY hKey, DWORD dwIndex, LPSTR lpName, LPDWORD lpcbName, LPDWORD lpReserved, LPSTR lpClass, LPDWORD lpcbClass, FILETIME* lpftLastWriteTime);
export LONG  RegEnumKeyExW(in HKEY hKey, DWORD dwIndex, LPWSTR lpName, LPDWORD lpcbName, LPDWORD lpReserved, LPWSTR lpClass, LPDWORD lpcbClass, FILETIME* lpftLastWriteTime);
export LONG RegEnumValueA(in HKEY hKey, DWORD dwIndex, LPSTR lpValueName, LPDWORD lpcbValueName, LPDWORD lpReserved,
    LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData);
export LONG RegEnumValueW(in HKEY hKey, DWORD dwIndex, LPWSTR lpValueName, LPDWORD lpcbValueName, LPDWORD lpReserved,
    LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData);

export LONG RegCloseKey(in HKEY hKey);
export LONG RegFlushKey(in HKEY hKey);

export LONG RegOpenKeyA(in HKEY hKey, LPCSTR lpSubKey, PHKEY phkResult);
export LONG RegOpenKeyW(in HKEY hKey, LPCWSTR lpSubKey, PHKEY phkResult);
export LONG RegOpenKeyExA(in HKEY hKey, LPCSTR lpSubKey, DWORD ulOptions, REGSAM samDesired, PHKEY phkResult);
export LONG RegOpenKeyExW(in HKEY hKey, LPCWSTR lpSubKey, DWORD ulOptions, REGSAM samDesired, PHKEY phkResult);

export LONG RegQueryInfoKeyA(in HKEY hKey, LPSTR lpClass, LPDWORD lpcbClass,
    LPDWORD lpReserved, LPDWORD lpcSubKeys, LPDWORD lpcbMaxSubKeyLen, LPDWORD lpcbMaxClassLen,
    LPDWORD lpcValues, LPDWORD lpcbMaxValueNameLen, LPDWORD lpcbMaxValueLen, LPDWORD lpcbSecurityDescriptor,
    PFILETIME lpftLastWriteTime);
export LONG RegQueryInfoKeyW(in HKEY hKey, LPWSTR lpClass, LPDWORD lpcbClass,
    LPDWORD lpReserved, LPDWORD lpcSubKeys, LPDWORD lpcbMaxSubKeyLen, LPDWORD lpcbMaxClassLen,
    LPDWORD lpcValues, LPDWORD lpcbMaxValueNameLen, LPDWORD lpcbMaxValueLen, LPDWORD lpcbSecurityDescriptor,
    PFILETIME lpftLastWriteTime);

export LONG RegQueryValueA(in HKEY hKey, LPCSTR lpSubKey, LPSTR lpValue, LPLONG lpcbValue);
export LONG RegQueryValueW(in HKEY hKey, LPCWSTR lpSubKey, LPWSTR lpValue, LPLONG lpcbValue);
export LONG RegQueryValueExA(in HKEY hKey, LPCSTR lpValueName, LPDWORD lpReserved, LPDWORD lpType, LPVOID lpData, LPDWORD lpcbData);
export LONG RegQueryValueExW(in HKEY hKey, LPCWSTR lpValueName, LPDWORD lpReserved, LPDWORD lpType, LPVOID lpData, LPDWORD lpcbData);

export LONG RegCreateKeyExA(in HKEY hKey, LPCSTR lpSubKey, DWORD Reserved, LPSTR lpClass,
   DWORD dwOptions, REGSAM samDesired, SECURITY_ATTRIBUTES* lpSecurityAttributes,
    PHKEY phkResult, LPDWORD lpdwDisposition);
export LONG RegCreateKeyExW(in HKEY hKey, LPCWSTR lpSubKey, DWORD Reserved, LPWSTR lpClass,
   DWORD dwOptions, REGSAM samDesired, SECURITY_ATTRIBUTES* lpSecurityAttributes,
    PHKEY phkResult, LPDWORD lpdwDisposition);

export LONG RegSetValueExA(in HKEY hKey, LPCSTR lpValueName, DWORD Reserved, DWORD dwType, BYTE* lpData, DWORD cbData);
export LONG RegSetValueExW(in HKEY hKey, LPCWSTR lpValueName, DWORD Reserved, DWORD dwType, BYTE* lpData, DWORD cbData);

export LONG RegOpenCurrentUser(REGSAM samDesired, PHKEY phkResult);

export LONG RegConnectRegistryA(LPCSTR lpMachineName, HKEY hKey, PHKEY phkResult);
export LONG RegConnectRegistryW(LPCWSTR lpMachineName, HKEY hKey, PHKEY phkResult);
}

struct MEMORY_BASIC_INFORMATION {
    PVOID BaseAddress;
    PVOID AllocationBase;
    DWORD AllocationProtect;
    DWORD RegionSize;
    DWORD State;
    DWORD Protect;
    DWORD Type;
}
alias MEMORY_BASIC_INFORMATION* PMEMORY_BASIC_INFORMATION;

enum
{
    SECTION_QUERY       = 0x0001,
    SECTION_MAP_WRITE   = 0x0002,
    SECTION_MAP_READ    = 0x0004,
    SECTION_MAP_EXECUTE = 0x0008,
    SECTION_EXTEND_SIZE = 0x0010,

    SECTION_ALL_ACCESS = cast(int)(STANDARD_RIGHTS_REQUIRED|SECTION_QUERY| SECTION_MAP_WRITE | SECTION_MAP_READ | SECTION_MAP_EXECUTE | SECTION_EXTEND_SIZE),
    PAGE_NOACCESS          = 0x01,
    PAGE_READONLY          = 0x02,
    PAGE_READWRITE         = 0x04,
    PAGE_WRITECOPY         = 0x08,
    PAGE_EXECUTE           = 0x10,
    PAGE_EXECUTE_READ      = 0x20,
    PAGE_EXECUTE_READWRITE = 0x40,
    PAGE_EXECUTE_WRITECOPY = 0x80,
    PAGE_GUARD            = 0x100,
    PAGE_NOCACHE          = 0x200,
    MEM_COMMIT           = 0x1000,
    MEM_RESERVE          = 0x2000,
    MEM_DECOMMIT         = 0x4000,
    MEM_RELEASE          = 0x8000,
    MEM_FREE            = 0x10000,
    MEM_PRIVATE         = 0x20000,
    MEM_MAPPED          = 0x40000,
    MEM_RESET           = 0x80000,
    MEM_TOP_DOWN       = 0x100000,
    SEC_FILE           = 0x800000,
    SEC_IMAGE         = 0x1000000,
    SEC_RESERVE       = 0x4000000,
    SEC_COMMIT        = 0x8000000,
    SEC_NOCACHE      = 0x10000000,
    MEM_IMAGE        = SEC_IMAGE,
}

enum
{
    FILE_MAP_COPY =       SECTION_QUERY,
    FILE_MAP_WRITE =      SECTION_MAP_WRITE,
    FILE_MAP_READ =       SECTION_MAP_READ,
    FILE_MAP_ALL_ACCESS = SECTION_ALL_ACCESS,
}


//
// Define access rights to files and directories
//

//
// The FILE_READ_DATA and FILE_WRITE_DATA constants are also defined in
// devioctl.h as FILE_READ_ACCESS and FILE_WRITE_ACCESS. The values for these
// constants *MUST* always be in sync.
// The values are redefined in devioctl.h because they must be available to
// both DOS and NT.
//

enum
{
    FILE_READ_DATA =            ( 0x0001 ),   // file & pipe
    FILE_LIST_DIRECTORY =       ( 0x0001 ),    // directory

    FILE_WRITE_DATA =           ( 0x0002 ),    // file & pipe
    FILE_ADD_FILE =             ( 0x0002 ),    // directory

    FILE_APPEND_DATA =          ( 0x0004 ),    // file
    FILE_ADD_SUBDIRECTORY =     ( 0x0004 ),    // directory
    FILE_CREATE_PIPE_INSTANCE = ( 0x0004 ),    // named pipe

    FILE_READ_EA =              ( 0x0008 ),    // file & directory

    FILE_WRITE_EA =             ( 0x0010 ),    // file & directory

    FILE_EXECUTE =              ( 0x0020 ),    // file
    FILE_TRAVERSE =             ( 0x0020 ),    // directory

    FILE_DELETE_CHILD =         ( 0x0040 ),    // directory

    FILE_READ_ATTRIBUTES =      ( 0x0080 ),    // all

    FILE_WRITE_ATTRIBUTES =     ( 0x0100 ),    // all

    FILE_ALL_ACCESS =       cast(int)(STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1FF),

    FILE_GENERIC_READ =         cast(int)(STANDARD_RIGHTS_READ  | FILE_READ_DATA |  FILE_READ_ATTRIBUTES |                 FILE_READ_EA |  SYNCHRONIZE),

    FILE_GENERIC_WRITE =        cast(int)(STANDARD_RIGHTS_WRITE | FILE_WRITE_DATA |  FILE_WRITE_ATTRIBUTES |                      FILE_WRITE_EA  |  FILE_APPEND_DATA |  SYNCHRONIZE),

    FILE_GENERIC_EXECUTE =      cast(int)(STANDARD_RIGHTS_EXECUTE | FILE_READ_ATTRIBUTES |                 FILE_EXECUTE |  SYNCHRONIZE),
}

export @nogc
{
 BOOL  FreeResource(HGLOBAL hResData);
 LPVOID LockResource(HGLOBAL hResData);
 BOOL GlobalUnlock(HGLOBAL hMem);
 HGLOBAL GlobalFree(HGLOBAL hMem);
 UINT GlobalCompact(DWORD dwMinFree);
 void GlobalFix(HGLOBAL hMem);
 void GlobalUnfix(HGLOBAL hMem);
 LPVOID GlobalWire(HGLOBAL hMem);
 BOOL GlobalUnWire(HGLOBAL hMem);
 void GlobalMemoryStatus(LPMEMORYSTATUS lpBuffer);
 HLOCAL LocalAlloc(UINT uFlags, UINT uBytes);
 HLOCAL LocalReAlloc(HLOCAL hMem, UINT uBytes, UINT uFlags);
 LPVOID LocalLock(HLOCAL hMem);
 HLOCAL LocalHandle(LPCVOID pMem);
 BOOL LocalUnlock(HLOCAL hMem);
 UINT LocalSize(HLOCAL hMem);
 UINT LocalFlags(HLOCAL hMem);
 HLOCAL LocalFree(HLOCAL hMem);
 UINT LocalShrink(HLOCAL hMem, UINT cbNewSize);
 UINT LocalCompact(UINT uMinFree);
 BOOL FlushInstructionCache(HANDLE hProcess, LPCVOID lpBaseAddress, DWORD dwSize);
 LPVOID VirtualAlloc(LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
 BOOL VirtualFree(LPVOID lpAddress, SIZE_T dwSize, DWORD dwFreeType);
 BOOL VirtualProtect(LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
 SIZE_T VirtualQuery(LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, SIZE_T dwLength);
 LPVOID VirtualAllocEx(HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect);
 BOOL VirtualFreeEx(HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD dwFreeType);
 BOOL VirtualProtectEx(HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
 SIZE_T VirtualQueryEx(HANDLE hProcess, LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, SIZE_T dwLength);
}

struct SYSTEMTIME
{
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
}

struct TIME_ZONE_INFORMATION {
    LONG Bias;
    WCHAR[32] StandardName;
    SYSTEMTIME StandardDate;
    LONG StandardBias;
    WCHAR[32] DaylightName;
    SYSTEMTIME DaylightDate;
    LONG DaylightBias;
}

struct REG_TZI_FORMAT
{
    LONG Bias;
    LONG StandardBias;
    LONG DaylightBias;
    SYSTEMTIME StandardDate;
    SYSTEMTIME DaylightDate;
}

enum
{
    TIME_ZONE_ID_UNKNOWN =  0,
    TIME_ZONE_ID_STANDARD = 1,
    TIME_ZONE_ID_DAYLIGHT = 2,
}

@nogc
{
export void GetSystemTime(SYSTEMTIME* lpSystemTime);
export BOOL GetFileTime(HANDLE hFile, FILETIME *lpCreationTime, FILETIME *lpLastAccessTime, FILETIME *lpLastWriteTime);
export void GetSystemTimeAsFileTime(FILETIME* lpSystemTimeAsFileTime);
export BOOL SetSystemTime(SYSTEMTIME* lpSystemTime);
export BOOL SetFileTime(HANDLE hFile, in FILETIME *lpCreationTime, in FILETIME *lpLastAccessTime, in FILETIME *lpLastWriteTime);
export void GetLocalTime(SYSTEMTIME* lpSystemTime);
export BOOL SetLocalTime(SYSTEMTIME* lpSystemTime);
export BOOL SystemTimeToTzSpecificLocalTime(TIME_ZONE_INFORMATION* lpTimeZoneInformation, SYSTEMTIME* lpUniversalTime, SYSTEMTIME* lpLocalTime);
export BOOL TzSpecificLocalTimeToSystemTime(TIME_ZONE_INFORMATION* lpTimeZoneInformation, SYSTEMTIME* lpLocalTime, SYSTEMTIME* lpUniversalTime);
export DWORD GetTimeZoneInformation(TIME_ZONE_INFORMATION* lpTimeZoneInformation);
export BOOL SetTimeZoneInformation(TIME_ZONE_INFORMATION* lpTimeZoneInformation);

export BOOL SystemTimeToFileTime(in SYSTEMTIME *lpSystemTime, FILETIME* lpFileTime);
export BOOL FileTimeToLocalFileTime(in FILETIME *lpFileTime, FILETIME* lpLocalFileTime);
export BOOL LocalFileTimeToFileTime(in FILETIME *lpLocalFileTime, FILETIME* lpFileTime);
export BOOL FileTimeToSystemTime(in FILETIME *lpFileTime, SYSTEMTIME* lpSystemTime);
export LONG CompareFileTime(in FILETIME *lpFileTime1, in FILETIME *lpFileTime2);
export BOOL FileTimeToDosDateTime(in FILETIME *lpFileTime, WORD* lpFatDate, WORD* lpFatTime);
export BOOL DosDateTimeToFileTime(WORD wFatDate, WORD wFatTime, FILETIME* lpFileTime);
export DWORD GetTickCount();
export BOOL SetSystemTimeAdjustment(DWORD dwTimeAdjustment, BOOL bTimeAdjustmentDisabled);
export BOOL GetSystemTimeAdjustment(DWORD* lpTimeAdjustment, DWORD* lpTimeIncrement, BOOL* lpTimeAdjustmentDisabled);
export DWORD FormatMessageA(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPSTR lpBuffer, DWORD nSize, void* *Arguments);
export DWORD FormatMessageW(DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPWSTR lpBuffer, DWORD nSize, void* *Arguments);
}

enum
{
    FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100,
    FORMAT_MESSAGE_IGNORE_INSERTS =  0x00000200,
    FORMAT_MESSAGE_FROM_STRING =     0x00000400,
    FORMAT_MESSAGE_FROM_HMODULE =    0x00000800,
    FORMAT_MESSAGE_FROM_SYSTEM =     0x00001000,
    FORMAT_MESSAGE_ARGUMENT_ARRAY =  0x00002000,
    FORMAT_MESSAGE_MAX_WIDTH_MASK =  0x000000FF,
};


//
//  Language IDs.
//
//  The following two combinations of primary language ID and
//  sublanguage ID have special semantics:
//
//    Primary Language ID   Sublanguage ID      Result
//    -------------------   ---------------     ------------------------
//    LANG_NEUTRAL          SUBLANG_NEUTRAL     Language neutral
//    LANG_NEUTRAL          SUBLANG_DEFAULT     User default language
//    LANG_NEUTRAL          SUBLANG_SYS_DEFAULT System default language
//

//
//  Primary language IDs.
//

enum
{
    LANG_NEUTRAL                     = 0x00,

    LANG_AFRIKAANS                   = 0x36,
    LANG_ALBANIAN                    = 0x1c,
    LANG_ARABIC                      = 0x01,
    LANG_BASQUE                      = 0x2d,
    LANG_BELARUSIAN                  = 0x23,
    LANG_BULGARIAN                   = 0x02,
    LANG_CATALAN                     = 0x03,
    LANG_CHINESE                     = 0x04,
    LANG_CROATIAN                    = 0x1a,
    LANG_CZECH                       = 0x05,
    LANG_DANISH                      = 0x06,
    LANG_DUTCH                       = 0x13,
    LANG_ENGLISH                     = 0x09,
    LANG_ESTONIAN                    = 0x25,
    LANG_FAEROESE                    = 0x38,
    LANG_FARSI                       = 0x29,
    LANG_FINNISH                     = 0x0b,
    LANG_FRENCH                      = 0x0c,
    LANG_GERMAN                      = 0x07,
    LANG_GREEK                       = 0x08,
    LANG_HEBREW                      = 0x0d,
    LANG_HUNGARIAN                   = 0x0e,
    LANG_ICELANDIC                   = 0x0f,
    LANG_INDONESIAN                  = 0x21,
    LANG_ITALIAN                     = 0x10,
    LANG_JAPANESE                    = 0x11,
    LANG_KOREAN                      = 0x12,
    LANG_LATVIAN                     = 0x26,
    LANG_LITHUANIAN                  = 0x27,
    LANG_NORWEGIAN                   = 0x14,
    LANG_POLISH                      = 0x15,
    LANG_PORTUGUESE                  = 0x16,
    LANG_ROMANIAN                    = 0x18,
    LANG_RUSSIAN                     = 0x19,
    LANG_SERBIAN                     = 0x1a,
    LANG_SLOVAK                      = 0x1b,
    LANG_SLOVENIAN                   = 0x24,
    LANG_SPANISH                     = 0x0a,
    LANG_SWEDISH                     = 0x1d,
    LANG_THAI                        = 0x1e,
    LANG_TURKISH                     = 0x1f,
    LANG_UKRAINIAN                   = 0x22,
    LANG_VIETNAMESE                  = 0x2a,
}
//
//  Sublanguage IDs.
//
//  The name immediately following SUBLANG_ dictates which primary
//  language ID that sublanguage ID can be combined with to form a
//  valid language ID.
//
enum
{
    SUBLANG_NEUTRAL =                  0x00,    // language neutral
    SUBLANG_DEFAULT =                  0x01,    // user default
    SUBLANG_SYS_DEFAULT =              0x02,    // system default

    SUBLANG_ARABIC_SAUDI_ARABIA =      0x01,    // Arabic (Saudi Arabia)
    SUBLANG_ARABIC_IRAQ =              0x02,    // Arabic (Iraq)
    SUBLANG_ARABIC_EGYPT =             0x03,    // Arabic (Egypt)
    SUBLANG_ARABIC_LIBYA =             0x04,    // Arabic (Libya)
    SUBLANG_ARABIC_ALGERIA =           0x05,    // Arabic (Algeria)
    SUBLANG_ARABIC_MOROCCO =           0x06,    // Arabic (Morocco)
    SUBLANG_ARABIC_TUNISIA =           0x07,    // Arabic (Tunisia)
    SUBLANG_ARABIC_OMAN =              0x08,    // Arabic (Oman)
    SUBLANG_ARABIC_YEMEN =             0x09,    // Arabic (Yemen)
    SUBLANG_ARABIC_SYRIA =             0x0a,    // Arabic (Syria)
    SUBLANG_ARABIC_JORDAN =            0x0b,    // Arabic (Jordan)
    SUBLANG_ARABIC_LEBANON =           0x0c,    // Arabic (Lebanon)
    SUBLANG_ARABIC_KUWAIT =            0x0d,    // Arabic (Kuwait)
    SUBLANG_ARABIC_UAE =               0x0e,    // Arabic (U.A.E)
    SUBLANG_ARABIC_BAHRAIN =           0x0f,    // Arabic (Bahrain)
    SUBLANG_ARABIC_QATAR =             0x10,    // Arabic (Qatar)
    SUBLANG_CHINESE_TRADITIONAL =      0x01,    // Chinese (Taiwan)
    SUBLANG_CHINESE_SIMPLIFIED =       0x02,    // Chinese (PR China)
    SUBLANG_CHINESE_HONGKONG =         0x03,    // Chinese (Hong Kong)
    SUBLANG_CHINESE_SINGAPORE =        0x04,    // Chinese (Singapore)
    SUBLANG_DUTCH =                    0x01,    // Dutch
    SUBLANG_DUTCH_BELGIAN =            0x02,    // Dutch (Belgian)
    SUBLANG_ENGLISH_US =               0x01,    // English (USA)
    SUBLANG_ENGLISH_UK =               0x02,    // English (UK)
    SUBLANG_ENGLISH_AUS =              0x03,    // English (Australian)
    SUBLANG_ENGLISH_CAN =              0x04,    // English (Canadian)
    SUBLANG_ENGLISH_NZ =               0x05,    // English (New Zealand)
    SUBLANG_ENGLISH_EIRE =             0x06,    // English (Irish)
    SUBLANG_ENGLISH_SOUTH_AFRICA =     0x07,    // English (South Africa)
    SUBLANG_ENGLISH_JAMAICA =          0x08,    // English (Jamaica)
    SUBLANG_ENGLISH_CARIBBEAN =        0x09,    // English (Caribbean)
    SUBLANG_ENGLISH_BELIZE =           0x0a,    // English (Belize)
    SUBLANG_ENGLISH_TRINIDAD =         0x0b,    // English (Trinidad)
    SUBLANG_FRENCH =                   0x01,    // French
    SUBLANG_FRENCH_BELGIAN =           0x02,    // French (Belgian)
    SUBLANG_FRENCH_CANADIAN =          0x03,    // French (Canadian)
    SUBLANG_FRENCH_SWISS =             0x04,    // French (Swiss)
    SUBLANG_FRENCH_LUXEMBOURG =        0x05,    // French (Luxembourg)
    SUBLANG_GERMAN =                   0x01,    // German
    SUBLANG_GERMAN_SWISS =             0x02,    // German (Swiss)
    SUBLANG_GERMAN_AUSTRIAN =          0x03,    // German (Austrian)
    SUBLANG_GERMAN_LUXEMBOURG =        0x04,    // German (Luxembourg)
    SUBLANG_GERMAN_LIECHTENSTEIN =     0x05,    // German (Liechtenstein)
    SUBLANG_ITALIAN =                  0x01,    // Italian
    SUBLANG_ITALIAN_SWISS =            0x02,    // Italian (Swiss)
    SUBLANG_KOREAN =                   0x01,    // Korean (Extended Wansung)
    SUBLANG_KOREAN_JOHAB =             0x02,    // Korean (Johab)
    SUBLANG_NORWEGIAN_BOKMAL =         0x01,    // Norwegian (Bokmal)
    SUBLANG_NORWEGIAN_NYNORSK =        0x02,    // Norwegian (Nynorsk)
    SUBLANG_PORTUGUESE =               0x02,    // Portuguese
    SUBLANG_PORTUGUESE_BRAZILIAN =     0x01,    // Portuguese (Brazilian)
    SUBLANG_SERBIAN_LATIN =            0x02,    // Serbian (Latin)
    SUBLANG_SERBIAN_CYRILLIC =         0x03,    // Serbian (Cyrillic)
    SUBLANG_SPANISH =                  0x01,    // Spanish (Castilian)
    SUBLANG_SPANISH_MEXICAN =          0x02,    // Spanish (Mexican)
    SUBLANG_SPANISH_MODERN =           0x03,    // Spanish (Modern)
    SUBLANG_SPANISH_GUATEMALA =        0x04,    // Spanish (Guatemala)
    SUBLANG_SPANISH_COSTA_RICA =       0x05,    // Spanish (Costa Rica)
    SUBLANG_SPANISH_PANAMA =           0x06,    // Spanish (Panama)
    SUBLANG_SPANISH_DOMINICAN_REPUBLIC = 0x07,  // Spanish (Dominican Republic)
    SUBLANG_SPANISH_VENEZUELA =        0x08,    // Spanish (Venezuela)
    SUBLANG_SPANISH_COLOMBIA =         0x09,    // Spanish (Colombia)
    SUBLANG_SPANISH_PERU =             0x0a,    // Spanish (Peru)
    SUBLANG_SPANISH_ARGENTINA =        0x0b,    // Spanish (Argentina)
    SUBLANG_SPANISH_ECUADOR =          0x0c,    // Spanish (Ecuador)
    SUBLANG_SPANISH_CHILE =            0x0d,    // Spanish (Chile)
    SUBLANG_SPANISH_URUGUAY =          0x0e,    // Spanish (Uruguay)
    SUBLANG_SPANISH_PARAGUAY =         0x0f,    // Spanish (Paraguay)
    SUBLANG_SPANISH_BOLIVIA =          0x10,    // Spanish (Bolivia)
    SUBLANG_SPANISH_EL_SALVADOR =      0x11,    // Spanish (El Salvador)
    SUBLANG_SPANISH_HONDURAS =         0x12,    // Spanish (Honduras)
    SUBLANG_SPANISH_NICARAGUA =        0x13,    // Spanish (Nicaragua)
    SUBLANG_SPANISH_PUERTO_RICO =      0x14,    // Spanish (Puerto Rico)
    SUBLANG_SWEDISH =                  0x01,    // Swedish
    SUBLANG_SWEDISH_FINLAND =          0x02,    // Swedish (Finland)
}
//
//  Sorting IDs.
//

enum
{
    SORT_DEFAULT                   = 0x0,    // sorting default

    SORT_JAPANESE_XJIS             = 0x0,    // Japanese XJIS order
    SORT_JAPANESE_UNICODE          = 0x1,    // Japanese Unicode order

    SORT_CHINESE_BIG5              = 0x0,    // Chinese BIG5 order
    SORT_CHINESE_PRCP              = 0x0,    // PRC Chinese Phonetic order
    SORT_CHINESE_UNICODE           = 0x1,    // Chinese Unicode order
    SORT_CHINESE_PRC               = 0x2,    // PRC Chinese Stroke Count order

    SORT_KOREAN_KSC                = 0x0,    // Korean KSC order
    SORT_KOREAN_UNICODE            = 0x1,    // Korean Unicode order

    SORT_GERMAN_PHONE_BOOK         = 0x1,    // German Phone Book order
}

// end_r_winnt

//
//  A language ID is a 16 bit value which is the combination of a
//  primary language ID and a secondary language ID.  The bits are
//  allocated as follows:
//
//       +-----------------------+-------------------------+
//       |     Sublanguage ID    |   Primary Language ID   |
//       +-----------------------+-------------------------+
//        15                   10 9                       0   bit
//
//
//  Language ID creation/extraction macros:
//
//    MAKELANGID    - construct language id from a primary language id and
//                    a sublanguage id.
//    PRIMARYLANGID - extract primary language id from a language id.
//    SUBLANGID     - extract sublanguage id from a language id.
//

pure @nogc
{
int MAKELANGID(int p, int s) { return ((cast(WORD)s) << 10) | cast(WORD)p; }
WORD PRIMARYLANGID(int lgid) { return cast(WORD)(lgid & 0x3ff); }
WORD SUBLANGID(int lgid)     { return cast(WORD)(lgid >> 10); }
}

version (Win64)
{
    enum
    {
        CONTEXT_AMD64 =  0x100000,


        CONTEXT_CONTROL = (CONTEXT_AMD64 | 0x1L),
        CONTEXT_INTEGER = (CONTEXT_AMD64 | 0x2L),
        CONTEXT_SEGMENTS = (CONTEXT_AMD64 | 0x4L),
        CONTEXT_FLOATING_POINT =  (CONTEXT_AMD64 | 0x8L),
        CONTEXT_DEBUG_REGISTERS = (CONTEXT_AMD64 | 0x10L),

        CONTEXT_FULL = (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_FLOATING_POINT),

        CONTEXT_ALL = (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS | CONTEXT_FLOATING_POINT | CONTEXT_DEBUG_REGISTERS),

        CONTEXT_EXCEPTION_ACTIVE = 0x8000000,
        CONTEXT_SERVICE_ACTIVE = 0x10000000,
        CONTEXT_EXCEPTION_REQUEST = 0x40000000,
        CONTEXT_EXCEPTION_REPORTING = 0x80000000,


        // Define initial MxCsr and FpCsr control.

        INITIAL_MXCSR = 0x1f80,            // initial MXCSR value
        INITIAL_FPCSR = 0x027f,            // initial FPCSR value
    }


    // Copied from Public Domain w64 mingw-runtime package's winnt.h.

    align(16) struct M128A
    {
        ULONGLONG Low;
        LONGLONG High;
    }
    alias M128A* PM128A;

    struct XMM_SAVE_AREA32
    {
        WORD ControlWord;
        WORD StatusWord;
        BYTE TagWord;
        BYTE Reserved1;
        WORD ErrorOpcode;
        DWORD ErrorOffset;
        WORD ErrorSelector;
        WORD Reserved2;
        DWORD DataOffset;
        WORD DataSelector;
        WORD Reserved3;
        DWORD MxCsr;
        DWORD MxCsr_Mask;
        M128A[8] FloatRegisters;
        M128A[16] XmmRegisters;
        BYTE[96] Reserved4;
    }
    alias XMM_SAVE_AREA32 PXMM_SAVE_AREA32;

    align(16) struct CONTEXT // sizeof(1232)
    {
        DWORD64 P1Home;
        DWORD64 P2Home;
        DWORD64 P3Home;
        DWORD64 P4Home;
        DWORD64 P5Home;
        DWORD64 P6Home;
        DWORD ContextFlags;
        DWORD MxCsr;
        WORD SegCs;
        WORD SegDs;
        WORD SegEs;
        WORD SegFs;
        WORD SegGs;
        WORD SegSs;
        DWORD EFlags;
        DWORD64 Dr0;
        DWORD64 Dr1;
        DWORD64 Dr2;
        DWORD64 Dr3;
        DWORD64 Dr6;
        DWORD64 Dr7;
        DWORD64 Rax;
        DWORD64 Rcx;
        DWORD64 Rdx;
        DWORD64 Rbx;
        DWORD64 Rsp;
        DWORD64 Rbp;
        DWORD64 Rsi;
        DWORD64 Rdi;
        DWORD64 R8;
        DWORD64 R9;
        DWORD64 R10;
        DWORD64 R11;
        DWORD64 R12;
        DWORD64 R13;
        DWORD64 R14;
        DWORD64 R15;
        DWORD64 Rip;
        union
        {
            XMM_SAVE_AREA32 FltSave;
            XMM_SAVE_AREA32 FloatSave;
            struct
            {
                M128A[2] Header;
                M128A[8] Legacy;
                M128A Xmm0;
                M128A Xmm1;
                M128A Xmm2;
                M128A Xmm3;
                M128A Xmm4;
                M128A Xmm5;
                M128A Xmm6;
                M128A Xmm7;
                M128A Xmm8;
                M128A Xmm9;
                M128A Xmm10;
                M128A Xmm11;
                M128A Xmm12;
                M128A Xmm13;
                M128A Xmm14;
                M128A Xmm15;
            };
        };
        M128A[26] VectorRegister;
        DWORD64 VectorControl;
        DWORD64 DebugControl;
        DWORD64 LastBranchToRip;
        DWORD64 LastBranchFromRip;
        DWORD64 LastExceptionToRip;
        DWORD64 LastExceptionFromRip;
    }
}
else version (Win32)
{
    enum
    {
        SIZE_OF_80387_REGISTERS =      80,
        //
        // The following flags control the contents of the CONTEXT structure.
        //
        CONTEXT_i386 =    0x00010000,    // this assumes that i386 and
        CONTEXT_i486 =    0x00010000,    // i486 have identical context records

        CONTEXT_CONTROL =         (CONTEXT_i386 | 0x00000001), // SS:SP, CS:IP, FLAGS, BP
        CONTEXT_INTEGER =         (CONTEXT_i386 | 0x00000002), // AX, BX, CX, DX, SI, DI
        CONTEXT_SEGMENTS =        (CONTEXT_i386 | 0x00000004), // DS, ES, FS, GS
        CONTEXT_FLOATING_POINT =  (CONTEXT_i386 | 0x00000008), // 387 state
        CONTEXT_DEBUG_REGISTERS = (CONTEXT_i386 | 0x00000010), // DB 0-3,6,7
        CONTEXT_EXTENDED_REGISTERS = (CONTEXT_i386 | 0x00000020L), // cpu specific extensions

        CONTEXT_FULL = (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS),

        CONTEXT_ALL = (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS |
                       CONTEXT_FLOATING_POINT | CONTEXT_DEBUG_REGISTERS |
                       CONTEXT_EXTENDED_REGISTERS),

        MAXIMUM_SUPPORTED_EXTENSION = 512
    }

    struct FLOATING_SAVE_AREA {
        DWORD   ControlWord;
        DWORD   StatusWord;
        DWORD   TagWord;
        DWORD   ErrorOffset;
        DWORD   ErrorSelector;
        DWORD   DataOffset;
        DWORD   DataSelector;
        BYTE[SIZE_OF_80387_REGISTERS]    RegisterArea;
        DWORD   Cr0NpxState;
    }

    struct CONTEXT
    {
        //
        // The flags values within this flag control the contents of
        // a CONTEXT record.
        //
        // If the context record is used as an input parameter, then
        // for each portion of the context record controlled by a flag
        // whose value is set, it is assumed that that portion of the
        // context record contains valid context. If the context record
        // is being used to modify a threads context, then only that
        // portion of the threads context will be modified.
        //
        // If the context record is used as an IN OUT parameter to capture
        // the context of a thread, then only those portions of the thread's
        // context corresponding to set flags will be returned.
        //
        // The context record is never used as an OUT only parameter.
        //

        DWORD ContextFlags;

        //
        // This section is specified/returned if CONTEXT_DEBUG_REGISTERS is
        // set in ContextFlags.  Note that CONTEXT_DEBUG_REGISTERS is NOT
        // included in CONTEXT_FULL.
        //

        DWORD   Dr0;
        DWORD   Dr1;
        DWORD   Dr2;
        DWORD   Dr3;
        DWORD   Dr6;
        DWORD   Dr7;

        //
        // This section is specified/returned if the
        // ContextFlags word contians the flag CONTEXT_FLOATING_POINT.
        //

        FLOATING_SAVE_AREA FloatSave;

        //
        // This section is specified/returned if the
        // ContextFlags word contians the flag CONTEXT_SEGMENTS.
        //

        DWORD   SegGs;
        DWORD   SegFs;
        DWORD   SegEs;
        DWORD   SegDs;

        //
        // This section is specified/returned if the
        // ContextFlags word contians the flag CONTEXT_INTEGER.
        //

        DWORD   Edi;
        DWORD   Esi;
        DWORD   Ebx;
        DWORD   Edx;
        DWORD   Ecx;
        DWORD   Eax;

        //
        // This section is specified/returned if the
        // ContextFlags word contians the flag CONTEXT_CONTROL.
        //

        DWORD   Ebp;
        DWORD   Eip;
        DWORD   SegCs;              // MUST BE SANITIZED
        DWORD   EFlags;             // MUST BE SANITIZED
        DWORD   Esp;
        DWORD   SegSs;

        //
        // This section is specified/returned if the ContextFlags word
        // contains the flag CONTEXT_EXTENDED_REGISTERS.
        // The format and contexts are processor specific
        //

        BYTE[MAXIMUM_SUPPORTED_EXTENSION] ExtendedRegisters;
    }
}

enum ADDRESS_MODE
{
    AddrMode1616,
    AddrMode1632,
    AddrModeReal,
    AddrModeFlat
}

struct ADDRESS
{
    DWORD         Offset;
    WORD          Segment;
    ADDRESS_MODE  Mode;
}

struct ADDRESS64
{
    DWORD64       Offset;
    WORD          Segment;
    ADDRESS_MODE  Mode;
}

struct KDHELP
{
    DWORD       Thread;
    DWORD       ThCallbackStack;
    DWORD       NextCallback;
    DWORD       FramePointer;
    DWORD       KiCallUserMode;
    DWORD       KeUserCallbackDispatcher;
    DWORD       SystemRangeStart;
    DWORD       ThCallbackBStore;
    DWORD       KiUserExceptionDispatcher;
    DWORD       StackBase;
    DWORD       StackLimit;
    DWORD[5]    Reserved;
}

struct KDHELP64
{
    DWORD64     Thread;
    DWORD       ThCallbackStack;
    DWORD       ThCallbackBStore;
    DWORD       NextCallback;
    DWORD       FramePointer;
    DWORD64     KiCallUserMode;
    DWORD64     KeUserCallbackDispatcher;
    DWORD64     SystemRangeStart;
    DWORD64     KiUserExceptionDispatcher;
    DWORD64     StackBase;
    DWORD64     StackLimit;
    DWORD64[5]  Reserved;
}

struct STACKFRAME
{
    ADDRESS     AddrPC;
    ADDRESS     AddrReturn;
    ADDRESS     AddrFrame;
    ADDRESS     AddrStack;
    PVOID       FuncTableEntry;
    DWORD[4]    Params;
    BOOL        Far;
    BOOL        Virtual;
    DWORD[3]    Reserved;
    KDHELP      KdHelp;
    ADDRESS     AddrBStore;
}

struct STACKFRAME64
{
    ADDRESS64   AddrPC;
    ADDRESS64   AddrReturn;
    ADDRESS64   AddrFrame;
    ADDRESS64   AddrStack;
    ADDRESS64   AddrBStore;
    PVOID       FuncTableEntry;
    DWORD64[4]  Params;
    BOOL        Far;
    BOOL        Virtual;
    DWORD64[3]  Reserved;
    KDHELP64    KdHelp;
}

enum
{
    THREAD_BASE_PRIORITY_LOWRT =  15,  // value that gets a thread to LowRealtime-1
    THREAD_BASE_PRIORITY_MAX =    2,   // maximum thread base priority boost
    THREAD_BASE_PRIORITY_MIN =    -2,  // minimum thread base priority boost
    THREAD_BASE_PRIORITY_IDLE =   -15, // value that gets a thread to idle

    THREAD_PRIORITY_LOWEST =          THREAD_BASE_PRIORITY_MIN,
    THREAD_PRIORITY_BELOW_NORMAL =    (THREAD_PRIORITY_LOWEST+1),
    THREAD_PRIORITY_NORMAL =          0,
    THREAD_PRIORITY_HIGHEST =         THREAD_BASE_PRIORITY_MAX,
    THREAD_PRIORITY_ABOVE_NORMAL =    (THREAD_PRIORITY_HIGHEST-1),
    THREAD_PRIORITY_ERROR_RETURN =    int.max,

    THREAD_PRIORITY_TIME_CRITICAL =   THREAD_BASE_PRIORITY_LOWRT,
    THREAD_PRIORITY_IDLE =            THREAD_BASE_PRIORITY_IDLE,
}

struct SYSTEM_INFO
{
    union
    {
        DWORD  dwOemId;

        struct
        {
            WORD wProcessorArchitecture;
            WORD wReserved;
        }
    }

    DWORD     dwPageSize;
    LPVOID    lpMinimumApplicationAddress;
    LPVOID    lpMaximumApplicationAddress;
    DWORD_PTR dwActiveProcessorMask;
    DWORD     dwNumberOfProcessors;
    DWORD     dwProcessorType;
    DWORD     dwAllocationGranularity;
    WORD      wProcessorLevel;
    WORD      wProcessorRevision;
}

alias SYSTEM_INFO* LPSYSTEM_INFO;

@nogc
{
export void GetSystemInfo(LPSYSTEM_INFO lpSystemInfo);
export void GetNativeSystemInfo(LPSYSTEM_INFO lpSystemInfo);
}

enum : DWORD
{
    MAX_COMPUTERNAME_LENGTH = 15,
}

@nogc
{
export BOOL GetComputerNameA(LPSTR lpBuffer, LPDWORD nSize);
export BOOL GetComputerNameW(LPWSTR lpBuffer, LPDWORD nSize);
export BOOL SetComputerNameA(LPCSTR lpComputerName);
export BOOL SetComputerNameW(LPCWSTR lpComputerName);
export BOOL GetUserNameA(LPSTR lpBuffer, LPDWORD lpnSize);
export BOOL GetUserNameW(LPWSTR lpBuffer, LPDWORD lpnSize);
export HANDLE GetCurrentThread();
export BOOL GetProcessTimes(HANDLE hProcess, LPFILETIME lpCreationTime, LPFILETIME lpExitTime, LPFILETIME lpKernelTime, LPFILETIME lpUserTime);
export HANDLE GetCurrentProcess();
export DWORD GetCurrentProcessId();
export BOOL DuplicateHandle (HANDLE sourceProcess, HANDLE sourceThread,
        HANDLE targetProcessHandle, HANDLE *targetHandle, DWORD access,
        BOOL inheritHandle, DWORD options);
export DWORD GetCurrentThreadId();
export BOOL SetThreadPriority(HANDLE hThread, int nPriority);
export BOOL SetThreadPriorityBoost(HANDLE hThread, BOOL bDisablePriorityBoost);
export BOOL GetThreadPriorityBoost(HANDLE hThread, PBOOL pDisablePriorityBoost);
export BOOL GetThreadTimes(HANDLE hThread, LPFILETIME lpCreationTime, LPFILETIME lpExitTime, LPFILETIME lpKernelTime, LPFILETIME lpUserTime);
export int GetThreadPriority(HANDLE hThread);
export BOOL GetThreadContext(HANDLE hThread, CONTEXT* lpContext);
export BOOL SetThreadContext(HANDLE hThread, CONTEXT* lpContext);
export DWORD SuspendThread(HANDLE hThread);
export DWORD ResumeThread(HANDLE hThread);
export DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
export DWORD WaitForMultipleObjects(DWORD nCount, HANDLE *lpHandles, BOOL bWaitAll, DWORD dwMilliseconds);
export void Sleep(DWORD dwMilliseconds);
export BOOL SwitchToThread();
}

// Synchronization

export @nogc
{
LONG InterlockedIncrement(LPLONG lpAddend);
LONG InterlockedDecrement(LPLONG lpAddend);
LONG InterlockedExchange(LPLONG Target, LONG Value);
LONG InterlockedExchangeAdd(LPLONG Addend, LONG Value);
LONG InterlockedCompareExchange(LONG *Destination, LONG Exchange, LONG Comperand);

void InitializeCriticalSection(CRITICAL_SECTION * lpCriticalSection) @trusted;
void EnterCriticalSection(CRITICAL_SECTION * lpCriticalSection) @nogc;
BOOL TryEnterCriticalSection(CRITICAL_SECTION * lpCriticalSection);
void LeaveCriticalSection(CRITICAL_SECTION * lpCriticalSection) @nogc;
void DeleteCriticalSection(CRITICAL_SECTION * lpCriticalSection);
}



@nogc
{
export BOOL QueryPerformanceCounter(long* lpPerformanceCount);
export BOOL QueryPerformanceFrequency(long* lpFrequency);
}

enum
{
    WM_NOTIFY =                       0x004E,
    WM_INPUTLANGCHANGEREQUEST =       0x0050,
    WM_INPUTLANGCHANGE =              0x0051,
    WM_TCARD =                        0x0052,
    WM_HELP =                         0x0053,
    WM_USERCHANGED =                  0x0054,
    WM_NOTIFYFORMAT =                 0x0055,

    NFR_ANSI =                             1,
    NFR_UNICODE =                          2,
    NF_QUERY =                             3,
    NF_REQUERY =                           4,

    WM_CONTEXTMENU =                  0x007B,
    WM_STYLECHANGING =                0x007C,
    WM_STYLECHANGED =                 0x007D,
    WM_DISPLAYCHANGE =                0x007E,
    WM_GETICON =                      0x007F,
    WM_SETICON =                      0x0080,



    WM_NCCREATE =                     0x0081,
    WM_NCDESTROY =                    0x0082,
    WM_NCCALCSIZE =                   0x0083,
    WM_NCHITTEST =                    0x0084,
    WM_NCPAINT =                      0x0085,
    WM_NCACTIVATE =                   0x0086,
    WM_GETDLGCODE =                   0x0087,

    WM_NCMOUSEMOVE =                  0x00A0,
    WM_NCLBUTTONDOWN =                0x00A1,
    WM_NCLBUTTONUP =                  0x00A2,
    WM_NCLBUTTONDBLCLK =              0x00A3,
    WM_NCRBUTTONDOWN =                0x00A4,
    WM_NCRBUTTONUP =                  0x00A5,
    WM_NCRBUTTONDBLCLK =              0x00A6,
    WM_NCMBUTTONDOWN =                0x00A7,
    WM_NCMBUTTONUP =                  0x00A8,
    WM_NCMBUTTONDBLCLK =              0x00A9,

    WM_KEYFIRST =                     0x0100,
    WM_KEYDOWN =                      0x0100,
    WM_KEYUP =                        0x0101,
    WM_CHAR =                         0x0102,
    WM_DEADCHAR =                     0x0103,
    WM_SYSKEYDOWN =                   0x0104,
    WM_SYSKEYUP =                     0x0105,
    WM_SYSCHAR =                      0x0106,
    WM_SYSDEADCHAR =                  0x0107,
    WM_KEYLAST =                      0x0108,


    WM_IME_STARTCOMPOSITION =         0x010D,
    WM_IME_ENDCOMPOSITION =           0x010E,
    WM_IME_COMPOSITION =              0x010F,
    WM_IME_KEYLAST =                  0x010F,


    WM_INITDIALOG =                   0x0110,
    WM_COMMAND =                      0x0111,
    WM_SYSCOMMAND =                   0x0112,
    WM_TIMER =                        0x0113,
    WM_HSCROLL =                      0x0114,
    WM_VSCROLL =                      0x0115,
    WM_INITMENU =                     0x0116,
    WM_INITMENUPOPUP =                0x0117,
    WM_MENUSELECT =                   0x011F,
    WM_MENUCHAR =                     0x0120,
    WM_ENTERIDLE =                    0x0121,

    WM_CTLCOLORMSGBOX =               0x0132,
    WM_CTLCOLOREDIT =                 0x0133,
    WM_CTLCOLORLISTBOX =              0x0134,
    WM_CTLCOLORBTN =                  0x0135,
    WM_CTLCOLORDLG =                  0x0136,
    WM_CTLCOLORSCROLLBAR =            0x0137,
    WM_CTLCOLORSTATIC =               0x0138,



    WM_MOUSEFIRST =                   0x0200,
    WM_MOUSEMOVE =                    0x0200,
    WM_LBUTTONDOWN =                  0x0201,
    WM_LBUTTONUP =                    0x0202,
    WM_LBUTTONDBLCLK =                0x0203,
    WM_RBUTTONDOWN =                  0x0204,
    WM_RBUTTONUP =                    0x0205,
    WM_RBUTTONDBLCLK =                0x0206,
    WM_MBUTTONDOWN =                  0x0207,
    WM_MBUTTONUP =                    0x0208,
    WM_MBUTTONDBLCLK =                0x0209,



    WM_MOUSELAST =                    0x0209,








    WM_PARENTNOTIFY =                 0x0210,
    MENULOOP_WINDOW =                 0,
    MENULOOP_POPUP =                  1,
    WM_ENTERMENULOOP =                0x0211,
    WM_EXITMENULOOP =                 0x0212,


    WM_NEXTMENU =                     0x0213,
}

enum
{
/*
 * Dialog Box Command IDs
 */
    IDOK =                1,
    IDCANCEL =            2,
    IDABORT =             3,
    IDRETRY =             4,
    IDIGNORE =            5,
    IDYES =               6,
    IDNO =                7,

    IDCLOSE =         8,
    IDHELP =          9,


// end_r_winuser



/*
 * Control Manager Structures and Definitions
 */



// begin_r_winuser

/*
 * Edit Control Styles
 */
    ES_LEFT =             0x0000,
    ES_CENTER =           0x0001,
    ES_RIGHT =            0x0002,
    ES_MULTILINE =        0x0004,
    ES_UPPERCASE =        0x0008,
    ES_LOWERCASE =        0x0010,
    ES_PASSWORD =         0x0020,
    ES_AUTOVSCROLL =      0x0040,
    ES_AUTOHSCROLL =      0x0080,
    ES_NOHIDESEL =        0x0100,
    ES_OEMCONVERT =       0x0400,
    ES_READONLY =         0x0800,
    ES_WANTRETURN =       0x1000,

    ES_NUMBER =           0x2000,


// end_r_winuser



/*
 * Edit Control Notification Codes
 */
    EN_SETFOCUS =         0x0100,
    EN_KILLFOCUS =        0x0200,
    EN_CHANGE =           0x0300,
    EN_UPDATE =           0x0400,
    EN_ERRSPACE =         0x0500,
    EN_MAXTEXT =          0x0501,
    EN_HSCROLL =          0x0601,
    EN_VSCROLL =          0x0602,


/* Edit control EM_SETMARGIN parameters */
    EC_LEFTMARGIN =       0x0001,
    EC_RIGHTMARGIN =      0x0002,
    EC_USEFONTINFO =      0xffff,




// begin_r_winuser

/*
 * Edit Control Messages
 */
    EM_GETSEL =               0x00B0,
    EM_SETSEL =               0x00B1,
    EM_GETRECT =              0x00B2,
    EM_SETRECT =              0x00B3,
    EM_SETRECTNP =            0x00B4,
    EM_SCROLL =               0x00B5,
    EM_LINESCROLL =           0x00B6,
    EM_SCROLLCARET =          0x00B7,
    EM_GETMODIFY =            0x00B8,
    EM_SETMODIFY =            0x00B9,
    EM_GETLINECOUNT =         0x00BA,
    EM_LINEINDEX =            0x00BB,
    EM_SETHANDLE =            0x00BC,
    EM_GETHANDLE =            0x00BD,
    EM_GETTHUMB =             0x00BE,
    EM_LINELENGTH =           0x00C1,
    EM_REPLACESEL =           0x00C2,
    EM_GETLINE =              0x00C4,
    EM_LIMITTEXT =            0x00C5,
    EM_CANUNDO =              0x00C6,
    EM_UNDO =                 0x00C7,
    EM_FMTLINES =             0x00C8,
    EM_LINEFROMCHAR =         0x00C9,
    EM_SETTABSTOPS =          0x00CB,
    EM_SETPASSWORDCHAR =      0x00CC,
    EM_EMPTYUNDOBUFFER =      0x00CD,
    EM_GETFIRSTVISIBLELINE =  0x00CE,
    EM_SETREADONLY =          0x00CF,
    EM_SETWORDBREAKPROC =     0x00D0,
    EM_GETWORDBREAKPROC =     0x00D1,
    EM_GETPASSWORDCHAR =      0x00D2,

    EM_SETMARGINS =           0x00D3,
    EM_GETMARGINS =           0x00D4,
    EM_SETLIMITTEXT =         EM_LIMITTEXT, /* ;win40 Name change */
    EM_GETLIMITTEXT =         0x00D5,
    EM_POSFROMCHAR =          0x00D6,
    EM_CHARFROMPOS =          0x00D7,



// end_r_winuser


/*
 * EDITWORDBREAKPROC code values
 */
    WB_LEFT =            0,
    WB_RIGHT =           1,
    WB_ISDELIMITER =     2,

// begin_r_winuser

/*
 * Button Control Styles
 */
    BS_PUSHBUTTON =       0x00000000,
    BS_DEFPUSHBUTTON =    0x00000001,
    BS_CHECKBOX =         0x00000002,
    BS_AUTOCHECKBOX =     0x00000003,
    BS_RADIOBUTTON =      0x00000004,
    BS_3STATE =           0x00000005,
    BS_AUTO3STATE =       0x00000006,
    BS_GROUPBOX =         0x00000007,
    BS_USERBUTTON =       0x00000008,
    BS_AUTORADIOBUTTON =  0x00000009,
    BS_OWNERDRAW =        0x0000000B,
    BS_LEFTTEXT =         0x00000020,

    BS_TEXT =             0x00000000,
    BS_ICON =             0x00000040,
    BS_BITMAP =           0x00000080,
    BS_LEFT =             0x00000100,
    BS_RIGHT =            0x00000200,
    BS_CENTER =           0x00000300,
    BS_TOP =              0x00000400,
    BS_BOTTOM =           0x00000800,
    BS_VCENTER =          0x00000C00,
    BS_PUSHLIKE =         0x00001000,
    BS_MULTILINE =        0x00002000,
    BS_NOTIFY =           0x00004000,
    BS_FLAT =             0x00008000,
    BS_RIGHTBUTTON =      BS_LEFTTEXT,



/*
 * User Button Notification Codes
 */
    BN_CLICKED =          0,
    BN_PAINT =            1,
    BN_HILITE =           2,
    BN_UNHILITE =         3,
    BN_DISABLE =          4,
    BN_DOUBLECLICKED =    5,

    BN_PUSHED =           BN_HILITE,
    BN_UNPUSHED =         BN_UNHILITE,
    BN_DBLCLK =           BN_DOUBLECLICKED,
    BN_SETFOCUS =         6,
    BN_KILLFOCUS =        7,

/*
 * Button Control Messages
 */
    BM_GETCHECK =        0x00F0,
    BM_SETCHECK =        0x00F1,
    BM_GETSTATE =        0x00F2,
    BM_SETSTATE =        0x00F3,
    BM_SETSTYLE =        0x00F4,

    BM_CLICK =           0x00F5,
    BM_GETIMAGE =        0x00F6,
    BM_SETIMAGE =        0x00F7,

    BST_UNCHECKED =      0x0000,
    BST_CHECKED =        0x0001,
    BST_INDETERMINATE =  0x0002,
    BST_PUSHED =         0x0004,
    BST_FOCUS =          0x0008,


/*
 * Static Control Constants
 */
    SS_LEFT =             0x00000000,
    SS_CENTER =           0x00000001,
    SS_RIGHT =            0x00000002,
    SS_ICON =             0x00000003,
    SS_BLACKRECT =        0x00000004,
    SS_GRAYRECT =         0x00000005,
    SS_WHITERECT =        0x00000006,
    SS_BLACKFRAME =       0x00000007,
    SS_GRAYFRAME =        0x00000008,
    SS_WHITEFRAME =       0x00000009,
    SS_USERITEM =         0x0000000A,
    SS_SIMPLE =           0x0000000B,
    SS_LEFTNOWORDWRAP =   0x0000000C,

    SS_OWNERDRAW =        0x0000000D,
    SS_BITMAP =           0x0000000E,
    SS_ENHMETAFILE =      0x0000000F,
    SS_ETCHEDHORZ =       0x00000010,
    SS_ETCHEDVERT =       0x00000011,
    SS_ETCHEDFRAME =      0x00000012,
    SS_TYPEMASK =         0x0000001F,

    SS_NOPREFIX =         0x00000080, /* Don't do "&" character translation */

    SS_NOTIFY =           0x00000100,
    SS_CENTERIMAGE =      0x00000200,
    SS_RIGHTJUST =        0x00000400,
    SS_REALSIZEIMAGE =    0x00000800,
    SS_SUNKEN =           0x00001000,
    SS_ENDELLIPSIS =      0x00004000,
    SS_PATHELLIPSIS =     0x00008000,
    SS_WORDELLIPSIS =     0x0000C000,
    SS_ELLIPSISMASK =     0x0000C000,


// end_r_winuser


/*
 * Static Control Mesages
 */
    STM_SETICON =         0x0170,
    STM_GETICON =         0x0171,

    STM_SETIMAGE =        0x0172,
    STM_GETIMAGE =        0x0173,
    STN_CLICKED =         0,
    STN_DBLCLK =          1,
    STN_ENABLE =          2,
    STN_DISABLE =         3,

    STM_MSGMAX =          0x0174,
}


enum
{
/*
 * Window Messages
 */

    WM_NULL =                         0x0000,
    WM_CREATE =                       0x0001,
    WM_DESTROY =                      0x0002,
    WM_MOVE =                         0x0003,
    WM_SIZE =                         0x0005,

    WM_ACTIVATE =                     0x0006,
/*
 * WM_ACTIVATE state values
 */
    WA_INACTIVE =     0,
    WA_ACTIVE =       1,
    WA_CLICKACTIVE =  2,

    WM_SETFOCUS =                     0x0007,
    WM_KILLFOCUS =                    0x0008,
    WM_ENABLE =                       0x000A,
    WM_SETREDRAW =                    0x000B,
    WM_SETTEXT =                      0x000C,
    WM_GETTEXT =                      0x000D,
    WM_GETTEXTLENGTH =                0x000E,
    WM_PAINT =                        0x000F,
    WM_CLOSE =                        0x0010,
    WM_QUERYENDSESSION =              0x0011,
    WM_QUIT =                         0x0012,
    WM_QUERYOPEN =                    0x0013,
    WM_ERASEBKGND =                   0x0014,
    WM_SYSCOLORCHANGE =               0x0015,
    WM_ENDSESSION =                   0x0016,
    WM_SHOWWINDOW =                   0x0018,
    WM_WININICHANGE =                 0x001A,

    WM_SETTINGCHANGE =                WM_WININICHANGE,



    WM_DEVMODECHANGE =                0x001B,
    WM_ACTIVATEAPP =                  0x001C,
    WM_FONTCHANGE =                   0x001D,
    WM_TIMECHANGE =                   0x001E,
    WM_CANCELMODE =                   0x001F,
    WM_SETCURSOR =                    0x0020,
    WM_MOUSEACTIVATE =                0x0021,
    WM_CHILDACTIVATE =                0x0022,
    WM_QUEUESYNC =                    0x0023,

    WM_GETMINMAXINFO =                0x0024,
}

struct RECT
{
    LONG    left;
    LONG    top;
    LONG    right;
    LONG    bottom;
}
alias RECT* PRECT, NPRECT, LPRECT;

struct PAINTSTRUCT {
    HDC         hdc;
    BOOL        fErase;
    RECT        rcPaint;
    BOOL        fRestore;
    BOOL        fIncUpdate;
    BYTE[32]    rgbReserved;
}
alias PAINTSTRUCT* PPAINTSTRUCT, NPPAINTSTRUCT, LPPAINTSTRUCT;

// flags for GetDCEx()

enum
{
    DCX_WINDOW =           0x00000001,
    DCX_CACHE =            0x00000002,
    DCX_NORESETATTRS =     0x00000004,
    DCX_CLIPCHILDREN =     0x00000008,
    DCX_CLIPSIBLINGS =     0x00000010,
    DCX_PARENTCLIP =       0x00000020,
    DCX_EXCLUDERGN =       0x00000040,
    DCX_INTERSECTRGN =     0x00000080,
    DCX_EXCLUDEUPDATE =    0x00000100,
    DCX_INTERSECTUPDATE =  0x00000200,
    DCX_LOCKWINDOWUPDATE = 0x00000400,
    DCX_VALIDATE =         0x00200000,
}

export @nogc
{
 BOOL UpdateWindow(HWND hWnd);
 HWND SetActiveWindow(HWND hWnd);
 HWND GetForegroundWindow();
 BOOL PaintDesktop(HDC hdc);
 BOOL SetForegroundWindow(HWND hWnd);
 HWND WindowFromDC(HDC hDC);
 HDC GetDC(HWND hWnd);
 HDC GetDCEx(HWND hWnd, HRGN hrgnClip, DWORD flags);
 HDC GetWindowDC(HWND hWnd);
 int ReleaseDC(HWND hWnd, HDC hDC);
 HDC BeginPaint(HWND hWnd, LPPAINTSTRUCT lpPaint);
 BOOL EndPaint(HWND hWnd, PAINTSTRUCT *lpPaint);
 BOOL GetUpdateRect(HWND hWnd, LPRECT lpRect, BOOL bErase);
 int GetUpdateRgn(HWND hWnd, HRGN hRgn, BOOL bErase);
 int SetWindowRgn(HWND hWnd, HRGN hRgn, BOOL bRedraw);
 int GetWindowRgn(HWND hWnd, HRGN hRgn);
 int ExcludeUpdateRgn(HDC hDC, HWND hWnd);
 BOOL InvalidateRect(HWND hWnd, RECT *lpRect, BOOL bErase);
 BOOL ValidateRect(HWND hWnd, RECT *lpRect);
 BOOL InvalidateRgn(HWND hWnd, HRGN hRgn, BOOL bErase);
 BOOL ValidateRgn(HWND hWnd, HRGN hRgn);
 BOOL RedrawWindow(HWND hWnd, RECT *lprcUpdate, HRGN hrgnUpdate, UINT flags);
}

// flags for RedrawWindow()
enum
{
    RDW_INVALIDATE =          0x0001,
    RDW_INTERNALPAINT =       0x0002,
    RDW_ERASE =               0x0004,
    RDW_VALIDATE =            0x0008,
    RDW_NOINTERNALPAINT =     0x0010,
    RDW_NOERASE =             0x0020,
    RDW_NOCHILDREN =          0x0040,
    RDW_ALLCHILDREN =         0x0080,
    RDW_UPDATENOW =           0x0100,
    RDW_ERASENOW =            0x0200,
    RDW_FRAME =               0x0400,
    RDW_NOFRAME =             0x0800,
}

export @nogc
{
 BOOL GetClientRect(HWND hWnd, LPRECT lpRect);
 BOOL GetWindowRect(HWND hWnd, LPRECT lpRect);
 BOOL AdjustWindowRect(LPRECT lpRect, DWORD dwStyle, BOOL bMenu);
 BOOL AdjustWindowRectEx(LPRECT lpRect, DWORD dwStyle, BOOL bMenu, DWORD dwExStyle);
 HFONT CreateFontA(int, int, int, int, int, DWORD,
                             DWORD, DWORD, DWORD, DWORD, DWORD,
                             DWORD, DWORD, LPCSTR);
 HFONT CreateFontW(int, int, int, int, int, DWORD,
                             DWORD, DWORD, DWORD, DWORD, DWORD,
                             DWORD, DWORD, LPCWSTR);
}

enum
{
    OUT_DEFAULT_PRECIS =          0,
    OUT_STRING_PRECIS =           1,
    OUT_CHARACTER_PRECIS =        2,
    OUT_STROKE_PRECIS =           3,
    OUT_TT_PRECIS =               4,
    OUT_DEVICE_PRECIS =           5,
    OUT_RASTER_PRECIS =           6,
    OUT_TT_ONLY_PRECIS =          7,
    OUT_OUTLINE_PRECIS =          8,
    OUT_SCREEN_OUTLINE_PRECIS =   9,

    CLIP_DEFAULT_PRECIS =     0,
    CLIP_CHARACTER_PRECIS =   1,
    CLIP_STROKE_PRECIS =      2,
    CLIP_MASK =               0xf,
    CLIP_LH_ANGLES =          (1<<4),
    CLIP_TT_ALWAYS =          (2<<4),
    CLIP_EMBEDDED =           (8<<4),

    DEFAULT_QUALITY =         0,
    DRAFT_QUALITY =           1,
    PROOF_QUALITY =           2,

    NONANTIALIASED_QUALITY =  3,
    ANTIALIASED_QUALITY =     4,


    DEFAULT_PITCH =           0,
    FIXED_PITCH =             1,
    VARIABLE_PITCH =          2,

    MONO_FONT =               8,


    ANSI_CHARSET =            0,
    DEFAULT_CHARSET =         1,
    SYMBOL_CHARSET =          2,
    SHIFTJIS_CHARSET =        128,
    HANGEUL_CHARSET =         129,
    GB2312_CHARSET =          134,
    CHINESEBIG5_CHARSET =     136,
    OEM_CHARSET =             255,

    JOHAB_CHARSET =           130,
    HEBREW_CHARSET =          177,
    ARABIC_CHARSET =          178,
    GREEK_CHARSET =           161,
    TURKISH_CHARSET =         162,
    VIETNAMESE_CHARSET =      163,
    THAI_CHARSET =            222,
    EASTEUROPE_CHARSET =      238,
    RUSSIAN_CHARSET =         204,

    MAC_CHARSET =             77,
    BALTIC_CHARSET =          186,

    FS_LATIN1 =               0x00000001L,
    FS_LATIN2 =               0x00000002L,
    FS_CYRILLIC =             0x00000004L,
    FS_GREEK =                0x00000008L,
    FS_TURKISH =              0x00000010L,
    FS_HEBREW =               0x00000020L,
    FS_ARABIC =               0x00000040L,
    FS_BALTIC =               0x00000080L,
    FS_VIETNAMESE =           0x00000100L,
    FS_THAI =                 0x00010000L,
    FS_JISJAPAN =             0x00020000L,
    FS_CHINESESIMP =          0x00040000L,
    FS_WANSUNG =              0x00080000L,
    FS_CHINESETRAD =          0x00100000L,
    FS_JOHAB =                0x00200000L,
    FS_SYMBOL =               cast(int)0x80000000L,


/* Font Families */
    FF_DONTCARE =         (0<<4), /* Don't care or don't know. */
    FF_ROMAN =            (1<<4), /* Variable stroke width, serifed. */
                                    /* Times Roman, Century Schoolbook, etc. */
    FF_SWISS =            (2<<4), /* Variable stroke width, sans-serifed. */
                                    /* Helvetica, Swiss, etc. */
    FF_MODERN =           (3<<4), /* Constant stroke width, serifed or sans-serifed. */
                                    /* Pica, Elite, Courier, etc. */
    FF_SCRIPT =           (4<<4), /* Cursive, etc. */
    FF_DECORATIVE =       (5<<4), /* Old English, etc. */

/* Font Weights */
    FW_DONTCARE =         0,
    FW_THIN =             100,
    FW_EXTRALIGHT =       200,
    FW_LIGHT =            300,
    FW_NORMAL =           400,
    FW_MEDIUM =           500,
    FW_SEMIBOLD =         600,
    FW_BOLD =             700,
    FW_EXTRABOLD =        800,
    FW_HEAVY =            900,

    FW_ULTRALIGHT =       FW_EXTRALIGHT,
    FW_REGULAR =          FW_NORMAL,
    FW_DEMIBOLD =         FW_SEMIBOLD,
    FW_ULTRABOLD =        FW_EXTRABOLD,
    FW_BLACK =            FW_HEAVY,

    PANOSE_COUNT =               10,
    PAN_FAMILYTYPE_INDEX =        0,
    PAN_SERIFSTYLE_INDEX =        1,
    PAN_WEIGHT_INDEX =            2,
    PAN_PROPORTION_INDEX =        3,
    PAN_CONTRAST_INDEX =          4,
    PAN_STROKEVARIATION_INDEX =   5,
    PAN_ARMSTYLE_INDEX =          6,
    PAN_LETTERFORM_INDEX =        7,
    PAN_MIDLINE_INDEX =           8,
    PAN_XHEIGHT_INDEX =           9,

    PAN_CULTURE_LATIN =           0,
}

struct RGBQUAD {
        BYTE    rgbBlue;
        BYTE    rgbGreen;
        BYTE    rgbRed;
        BYTE    rgbReserved;
}
alias RGBQUAD* LPRGBQUAD;

struct BITMAPINFOHEADER
{
        DWORD      biSize;
        LONG       biWidth;
        LONG       biHeight;
        WORD       biPlanes;
        WORD       biBitCount;
        DWORD      biCompression;
        DWORD      biSizeImage;
        LONG       biXPelsPerMeter;
        LONG       biYPelsPerMeter;
        DWORD      biClrUsed;
        DWORD      biClrImportant;
}
alias BITMAPINFOHEADER* LPBITMAPINFOHEADER, PBITMAPINFOHEADER;

struct BITMAPINFO {
    BITMAPINFOHEADER    bmiHeader;
    RGBQUAD[1]          bmiColors;
}
alias BITMAPINFO* LPBITMAPINFO, PBITMAPINFO;

struct PALETTEENTRY {
    BYTE        peRed;
    BYTE        peGreen;
    BYTE        peBlue;
    BYTE        peFlags;
}
alias PALETTEENTRY* PPALETTEENTRY, LPPALETTEENTRY;

struct LOGPALETTE {
    WORD        palVersion;
    WORD        palNumEntries;
    PALETTEENTRY[1]  palPalEntry;
}
alias LOGPALETTE* PLOGPALETTE, NPLOGPALETTE, LPLOGPALETTE;

/* Pixel format descriptor flags */
enum : DWORD
{
    /* pixel types */
    PFD_TYPE_RGBA = 0,
    PFD_TYPE_COLORINDEX = 1,

    /* layer types */
    PFD_MAIN_PLANE = 0,
    PFD_OVERLAY_PLANE = 1,
    PFD_UNDERLAY_PLANE = -1,

    /* PIXELFORMATDESCRIPTOR flags */
    PFD_DOUBLEBUFFER = 0x00000001,
    PFD_STEREO = 0x00000002,
    PFD_DRAW_TO_WINDOW = 0x00000004,
    PFD_DRAW_TO_BITMAP = 0x00000008,
    PFD_SUPPORT_GDI = 0x00000010,
    PFD_SUPPORT_OPENGL = 0x00000020,
    PFD_GENERIC_FORMAT = 0x00000040,
    PFD_NEED_PALETTE = 0x00000080,
    PFD_NEED_SYSTEM_PALETTE = 0x00000100,
    PFD_SWAP_EXCHANGE = 0x00000200,
    PFD_SWAP_COPY = 0x00000400,
    PFD_SWAP_LAYER_BUFFERS = 0x00000800,
    PFD_GENERIC_ACCELERATED = 0x00001000,
    PFD_SUPPORT_DIRECTDRAW = 0x00002000,
    PFD_DIRECT3D_ACCELERATED = 0x00004000,
    PFD_SUPPORT_COMPOSITION = 0x00008000,

    /* PIXELFORMATDESCRIPTOR flags for use in ChoosePixelFormat only */
    PFD_DEPTH_DONTCARE = 0x20000000,
    PFD_DOUBLEBUFFER_DONTCARE = 0x40000000,
    PFD_STEREO_DONTCARE = 0x80000000
}

/* Pixel format descriptor */
struct PIXELFORMATDESCRIPTOR
{
    WORD  nSize;
    WORD  nVersion;
    DWORD dwFlags;
    BYTE  iPixelType;
    BYTE  cColorBits;
    BYTE  cRedBits;
    BYTE  cRedShift;
    BYTE  cGreenBits;
    BYTE  cGreenShift;
    BYTE  cBlueBits;
    BYTE  cBlueShift;
    BYTE  cAlphaBits;
    BYTE  cAlphaShift;
    BYTE  cAccumBits;
    BYTE  cAccumRedBits;
    BYTE  cAccumGreenBits;
    BYTE  cAccumBlueBits;
    BYTE  cAccumAlphaBits;
    BYTE  cDepthBits;
    BYTE  cStencilBits;
    BYTE  cAuxBuffers;
    BYTE  iLayerType;
    BYTE  bReserved;
    DWORD dwLayerMask;
    DWORD dwVisibleMask;
    DWORD dwDamageMask;
}
alias PIXELFORMATDESCRIPTOR* PPIXELFORMATDESCRIPTOR, LPPIXELFORMATDESCRIPTOR;

export @nogc
{
 BOOL   RoundRect(HDC, int, int, int, int, int, int);
 BOOL   ResizePalette(HPALETTE, UINT);
 int    SaveDC(HDC);
 int    SelectClipRgn(HDC, HRGN);
 int    ExtSelectClipRgn(HDC, HRGN, int);
 int    SetMetaRgn(HDC);
 HGDIOBJ   SelectObject(HDC, HGDIOBJ);
 HPALETTE   SelectPalette(HDC, HPALETTE, BOOL);
 COLORREF   SetBkColor(HDC, COLORREF);
 int     SetBkMode(HDC, int);
 LONG    SetBitmapBits(HBITMAP, DWORD, void *);
 UINT    SetBoundsRect(HDC,   RECT *, UINT);
 int     SetDIBits(HDC, HBITMAP, UINT, UINT, void *, BITMAPINFO *, UINT);
 int     SetDIBitsToDevice(HDC, int, int, DWORD, DWORD, int,
        int, UINT, UINT, void *, BITMAPINFO *, UINT);
 DWORD   SetMapperFlags(HDC, DWORD);
 int     SetGraphicsMode(HDC hdc, int iMode);
 int     SetMapMode(HDC, int);
 HMETAFILE     SetMetaFileBitsEx(UINT, BYTE *);
 UINT    SetPaletteEntries(HPALETTE, UINT, UINT, PALETTEENTRY *);
 COLORREF   SetPixel(HDC, int, int, COLORREF);
 BOOL     SetPixelV(HDC, int, int, COLORREF);
 BOOL    SetPixelFormat(HDC, int, PIXELFORMATDESCRIPTOR *);
 int     ChoosePixelFormat(HDC, PIXELFORMATDESCRIPTOR *);
 BOOL    SwapBuffers(HDC);
 int     SetPolyFillMode(HDC, int);
 BOOL    StretchBlt(HDC, int, int, int, int, HDC, int, int, int, int, DWORD);
 BOOL    SetRectRgn(HRGN, int, int, int, int);
 int     StretchDIBits(HDC, int, int, int, int, int, int, int, int,
         void *, BITMAPINFO *, UINT, DWORD);
 int     SetROP2(HDC, int);
 int     SetStretchBltMode(HDC, int);
 UINT    SetSystemPaletteUse(HDC, UINT);
 int     SetTextCharacterExtra(HDC, int);
 COLORREF   SetTextColor(HDC, COLORREF);
 UINT    SetTextAlign(HDC, UINT);
 BOOL    SetTextJustification(HDC, int, int);
 BOOL    UpdateColors(HDC);
}

/* Text Alignment Options */
enum
{
    TA_NOUPDATECP =                0,
    TA_UPDATECP =                  1,

    TA_LEFT =                      0,
    TA_RIGHT =                     2,
    TA_CENTER =                    6,

    TA_TOP =                       0,
    TA_BOTTOM =                    8,
    TA_BASELINE =                  24,

    TA_RTLREADING =                256,
    TA_MASK =       (TA_BASELINE+TA_CENTER+TA_UPDATECP+TA_RTLREADING),
}

struct POINT
{
    LONG  x;
    LONG  y;
}
alias POINT* PPOINT, NPPOINT, LPPOINT;


export @nogc
{
 BOOL    MoveToEx(HDC, int, int, LPPOINT);
 BOOL    TextOutA(HDC, int, int, LPCSTR, int);
 BOOL    TextOutW(HDC, int, int, LPCWSTR, int);
}

@nogc
{
export void PostQuitMessage(int nExitCode);
export LRESULT DefWindowProcA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
export LRESULT DefWindowProcW(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
export HMODULE GetModuleHandleA(LPCSTR lpModuleName);
export HMODULE GetModuleHandleW(LPCWSTR lpModuleName);
}

alias LRESULT function (HWND, UINT, WPARAM, LPARAM) WNDPROC;

struct WNDCLASSEXA {
    UINT        cbSize;
    /* Win 3.x */
    UINT        style;
    WNDPROC     lpfnWndProc;
    int         cbClsExtra;
    int         cbWndExtra;
    HINSTANCE   hInstance;
    HICON       hIcon;
    HCURSOR     hCursor;
    HBRUSH      hbrBackground;
    LPCSTR      lpszMenuName;
    LPCSTR      lpszClassName;
    /* Win 4.0 */
    HICON       hIconSm;
}
alias WNDCLASSEXA* PWNDCLASSEXA, NPWNDCLASSEXA, LPWNDCLASSEXA;


struct WNDCLASSA {
    UINT        style;
    WNDPROC     lpfnWndProc;
    int         cbClsExtra;
    int         cbWndExtra;
    HINSTANCE   hInstance;
    HICON       hIcon;
    HCURSOR     hCursor;
    HBRUSH      hbrBackground;
    LPCSTR      lpszMenuName;
    LPCSTR      lpszClassName;
}
alias WNDCLASSA* PWNDCLASSA, NPWNDCLASSA, LPWNDCLASSA;
alias WNDCLASSA WNDCLASS;


struct WNDCLASSEXW {
    UINT        cbSize;
    /* Win 3.x */
    UINT        style;
    WNDPROC     lpfnWndProc;
    int         cbClsExtra;
    int         cbWndExtra;
    HINSTANCE   hInstance;
    HICON       hIcon;
    HCURSOR     hCursor;
    HBRUSH      hbrBackground;
    LPCWSTR     lpszMenuName;
    LPCWSTR     lpszClassName;
    /* Win 4.0 */
    HICON       hIconSm;
}


struct WNDCLASSW {
    UINT        style;
    WNDPROC     lpfnWndProc;
    int         cbClsExtra;
    int         cbWndExtra;
    HINSTANCE   hInstance;
    HICON       hIcon;
    HCURSOR     hCursor;
    HBRUSH      hbrBackground;
    LPCWSTR     lpszMenuName;
    LPCWSTR     lpszClassName;
}
alias WNDCLASSW* PWNDCLASSW, NPWNDCLASSW, LPWNDCLASSW;


/*
 * Window Styles
 */
enum : uint
{
    WS_OVERLAPPED =       0x00000000,
    WS_POPUP =            0x80000000,
    WS_CHILD =            0x40000000,
    WS_MINIMIZE =         0x20000000,
    WS_VISIBLE =          0x10000000,
    WS_DISABLED =         0x08000000,
    WS_CLIPSIBLINGS =     0x04000000,
    WS_CLIPCHILDREN =     0x02000000,
    WS_MAXIMIZE =         0x01000000,
    WS_CAPTION =          0x00C00000,  /* WS_BORDER | WS_DLGFRAME  */
    WS_BORDER =           0x00800000,
    WS_DLGFRAME =         0x00400000,
    WS_VSCROLL =          0x00200000,
    WS_HSCROLL =          0x00100000,
    WS_SYSMENU =          0x00080000,
    WS_THICKFRAME =       0x00040000,
    WS_GROUP =            0x00020000,
    WS_TABSTOP =          0x00010000,

    WS_MINIMIZEBOX =      0x00020000,
    WS_MAXIMIZEBOX =      0x00010000,

    WS_TILED =            WS_OVERLAPPED,
    WS_ICONIC =           WS_MINIMIZE,
    WS_SIZEBOX =          WS_THICKFRAME,

/*
 * Common Window Styles
 */
    WS_OVERLAPPEDWINDOW = (WS_OVERLAPPED |            WS_CAPTION |  WS_SYSMENU |  WS_THICKFRAME |            WS_MINIMIZEBOX |                 WS_MAXIMIZEBOX),
    WS_TILEDWINDOW =      WS_OVERLAPPEDWINDOW,
    WS_POPUPWINDOW =      (WS_POPUP |  WS_BORDER |  WS_SYSMENU),
    WS_CHILDWINDOW =      (WS_CHILD),
}

enum : uint
{
    WS_EX_ACCEPTFILES = 0x00000010,
    WS_EX_APPWINDOW = 0x00040000,
    WS_EX_CLIENTEDGE = 0x00000200,
    WS_EX_COMPOSITED = 0x02000000,
    WS_EX_CONTEXTHELP = 0x00000400,
    WS_EX_CONTROLPARENT = 0x00010000,
    WS_EX_DLGMODALFRAME = 0x00000001,
    WS_EX_LAYERED = 0x00080000,
    WS_EX_LAYOUTRTL = 0x00400000,
    WS_EX_LEFT = 0x00000000,
    WS_EX_LEFTSCROLLBAR = 0x00004000,
    WS_EX_LTRREADING = 0x00000000,
    WS_EX_MDICHILD = 0x00000040,
    WS_EX_NOACTIVATE = 0x08000000,
    WS_EX_NOINHERITLAYOUT = 0x00100000,
    WS_EX_NOPARENTNOTIFY = 0x00000004,
    WS_EX_RIGHT = 0x00001000,
    WS_EX_RIGHTSCROLLBAR = 0x00000000,
    WS_EX_RTLREADING = 0x00002000,
    WS_EX_STATICEDGE = 0x00020000,
    WS_EX_TOOLWINDOW = 0x00000080,
    WS_EX_TOPMOST = 0x00000008,
    WS_EX_TRANSPARENT = 0x00000020,
    WS_EX_WINDOWEDGE = 0x00000100,
    WS_EX_OVERLAPPEDWINDOW = (WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE),
    WS_EX_PALETTEWINDOW = (WS_EX_WINDOWEDGE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST),
}

/*
 * Class styles
 */
enum
{
    CS_VREDRAW =          0x0001,
    CS_HREDRAW =          0x0002,
    CS_KEYCVTWINDOW =     0x0004,
    CS_DBLCLKS =          0x0008,
    CS_OWNDC =            0x0020,
    CS_CLASSDC =          0x0040,
    CS_PARENTDC =         0x0080,
    CS_NOKEYCVT =         0x0100,
    CS_NOCLOSE =          0x0200,
    CS_SAVEBITS =         0x0800,
    CS_BYTEALIGNCLIENT =  0x1000,
    CS_BYTEALIGNWINDOW =  0x2000,
    CS_GLOBALCLASS =      0x4000,


    CS_IME =              0x00010000,
}

export @nogc
{
 HICON LoadIconA(HINSTANCE hInstance, LPCSTR lpIconName);
 HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
 HCURSOR LoadCursorA(HINSTANCE hInstance, LPCSTR lpCursorName);
 HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);
}


enum : LPSTR
{
    IDI_APPLICATION =     cast(LPSTR)(32512),

    IDC_ARROW =           cast(LPSTR)(32512),
    IDC_CROSS =           cast(LPSTR)(32515),
}


/*
 * Color Types
 */
enum
{
    CTLCOLOR_MSGBOX =         0,
    CTLCOLOR_EDIT =           1,
    CTLCOLOR_LISTBOX =        2,
    CTLCOLOR_BTN =            3,
    CTLCOLOR_DLG =            4,
    CTLCOLOR_SCROLLBAR =      5,
    CTLCOLOR_STATIC =         6,
    CTLCOLOR_MAX =            7,

    COLOR_SCROLLBAR =         0,
    COLOR_BACKGROUND =        1,
    COLOR_ACTIVECAPTION =     2,
    COLOR_INACTIVECAPTION =   3,
    COLOR_MENU =              4,
    COLOR_WINDOW =            5,
    COLOR_WINDOWFRAME =       6,
    COLOR_MENUTEXT =          7,
    COLOR_WINDOWTEXT =        8,
    COLOR_CAPTIONTEXT =       9,
    COLOR_ACTIVEBORDER =      10,
    COLOR_INACTIVEBORDER =    11,
    COLOR_APPWORKSPACE =      12,
    COLOR_HIGHLIGHT =         13,
    COLOR_HIGHLIGHTTEXT =     14,
    COLOR_BTNFACE =           15,
    COLOR_BTNSHADOW =         16,
    COLOR_GRAYTEXT =          17,
    COLOR_BTNTEXT =           18,
    COLOR_INACTIVECAPTIONTEXT = 19,
    COLOR_BTNHIGHLIGHT =      20,


    COLOR_3DDKSHADOW =        21,
    COLOR_3DLIGHT =           22,
    COLOR_INFOTEXT =          23,
    COLOR_INFOBK =            24,

    COLOR_DESKTOP =           COLOR_BACKGROUND,
    COLOR_3DFACE =            COLOR_BTNFACE,
    COLOR_3DSHADOW =          COLOR_BTNSHADOW,
    COLOR_3DHIGHLIGHT =       COLOR_BTNHIGHLIGHT,
    COLOR_3DHILIGHT =         COLOR_BTNHIGHLIGHT,
    COLOR_BTNHILIGHT =        COLOR_BTNHIGHLIGHT,
}

enum : int
{
    CW_USEDEFAULT = cast(int)0x80000000
}

/*
 * Special value for CreateWindow, et al.
 */
enum : HWND
{
    HWND_DESKTOP = cast(HWND)0,
}

@nogc
{
export ATOM RegisterClassA(in WNDCLASSA *lpWndClass);
export ATOM RegisterClassExA(in WNDCLASSEXA *lpWndClass);
export ATOM RegisterClassW(in WNDCLASSW *lpWndClass);
export ATOM RegisterClassExW(in WNDCLASSEXW *lpWndClass);

export HWND CreateWindowExA(
    DWORD dwExStyle,
    LPCSTR lpClassName,
    LPCSTR lpWindowName,
    DWORD dwStyle,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    HWND hWndParent ,
    HMENU hMenu,
    HINSTANCE hInstance,
    LPVOID lpParam);


HWND CreateWindowA(
    LPCSTR lpClassName,
    LPCSTR lpWindowName,
    DWORD dwStyle,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    HWND hWndParent ,
    HMENU hMenu,
    HINSTANCE hInstance,
    LPVOID lpParam)
{
    return CreateWindowExA(0, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWndParent, hMenu, hInstance, lpParam);
}


export HWND CreateWindowExW(
    DWORD dwExStyle,
    LPCWSTR lpClassName,
    LPCWSTR lpWindowName,
    DWORD dwStyle,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    HWND hWndParent,
    HMENU hMenu,
    HINSTANCE hInstance,
    LPVOID lpParam);


HWND CreateWindowW(
    LPCWSTR lpClassName,
    LPCWSTR lpWindowName,
    DWORD dwStyle,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    HWND hWndParent ,
    HMENU hMenu,
    HINSTANCE hInstance,
    LPVOID lpParam)
{
    return CreateWindowExW(0, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWndParent, hMenu, hInstance, lpParam);
}

export BOOL DestroyWindow(HWND hWnd);
export BOOL SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags);
}

enum : uint
{
    SWP_ASYNCWINDOWPOS = 0x4000,
    SWP_DEFERERASE = 0x2000,
    SWP_DRAWFRAME = 0x0020,
    SWP_FRAMECHANGED = 0x0020,
    SWP_HIDEWINDOW = 0x0080,
    SWP_NOACTIVATE = 0x0010,
    SWP_NOCOPYBITS = 0x0100,
    SWP_NOMOVE = 0x0002,
    SWP_NOOWNERZORDER = 0x0200,
    SWP_NOREDRAW = 0x0008,
    SWP_NOREPOSITION = 0x0200,
    SWP_NOSENDCHANGING = 0x0400,
    SWP_NOSIZE = 0x0001,
    SWP_NOZORDER = 0x0004,
    SWP_SHOWWINDOW = 0x0040,
}

/*
 * Message structure
 */
struct MSG {
    HWND        hwnd;
    UINT        message;
    WPARAM      wParam;
    LPARAM      lParam;
    DWORD       time;
    POINT       pt;
}
alias MSG* PMSG, NPMSG, LPMSG;

export @nogc
{
 BOOL GetMessageA(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax);
 BOOL GetMessageW(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax);
 BOOL TranslateMessage(MSG *lpMsg);
 LONG DispatchMessageA(in MSG *lpMsg);
 LONG DispatchMessageW(in MSG *lpMsg);
 BOOL PeekMessageA(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
 BOOL PeekMessageW(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
 HWND GetFocus();
}

/* http://msdn.microsoft.com/en-us/library/windows/desktop/ms683187(v=vs.85).aspx
According to MSDN about a value returned by GetEnvironmentString:
"Treat this memory as read-only; do not modify it directly.".
So return type of GetEnvironmentStrings is changed from LPWCH (as in *.h file)
to LPCWCH. FreeEnvironmentStrings's argument type is changed correspondingly.
*/
@nogc
{
export LPCWCH GetEnvironmentStringsW();
export BOOL FreeEnvironmentStringsW(LPCWCH lpszEnvironmentBlock);
export DWORD GetEnvironmentVariableW(LPCWSTR lpName, LPWSTR lpBuffer, DWORD nSize);
export BOOL  SetEnvironmentVariableW(LPCWSTR lpName, LPCWSTR lpValue);
export DWORD ExpandEnvironmentStringsA(LPCSTR lpSrc, LPSTR lpDst, DWORD nSize);
export DWORD ExpandEnvironmentStringsW(LPCWSTR lpSrc, LPWSTR lpDst, DWORD nSize);
}

export @nogc
{
 BOOL IsValidCodePage(UINT CodePage);
 UINT GetACP();
 UINT GetOEMCP();
 //BOOL GetCPInfo(UINT CodePage, LPCPINFO lpCPInfo);
 BOOL IsDBCSLeadByte(BYTE TestChar);
 BOOL IsDBCSLeadByteEx(UINT CodePage, BYTE TestChar);
 int MultiByteToWideChar(UINT CodePage, DWORD dwFlags, LPCSTR lpMultiByteStr, int cchMultiByte, LPWSTR lpWideCharStr, int cchWideChar);
 int WideCharToMultiByte(UINT CodePage, DWORD dwFlags, LPCWSTR lpWideCharStr, int cchWideChar, LPSTR lpMultiByteStr, int cchMultiByte, LPCSTR lpDefaultChar, LPBOOL lpUsedDefaultChar);
}

// Code pages
enum : UINT
{
    CP_UTF8 = 65001
}

@nogc
{
export HANDLE CreateFileMappingA(HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCSTR lpName);
export HANDLE CreateFileMappingW(HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCWSTR lpName);

export BOOL GetMailslotInfo(HANDLE hMailslot, LPDWORD lpMaxMessageSize, LPDWORD lpNextSize, LPDWORD lpMessageCount, LPDWORD lpReadTimeout);
export BOOL SetMailslotInfo(HANDLE hMailslot, DWORD lReadTimeout);
export LPVOID MapViewOfFile(HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, SIZE_T dwNumberOfBytesToMap);
export LPVOID MapViewOfFileEx(HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, SIZE_T dwNumberOfBytesToMap, LPVOID lpBaseAddress);
export BOOL FlushViewOfFile(LPCVOID lpBaseAddress, SIZE_T dwNumberOfBytesToFlush);
export BOOL UnmapViewOfFile(LPCVOID lpBaseAddress);

export  HGDIOBJ   GetStockObject(int);
export BOOL ShowWindow(HWND hWnd, int nCmdShow);
}

/* Stock Logical Objects */
enum
{
    WHITE_BRUSH =         0,
    LTGRAY_BRUSH =        1,
    GRAY_BRUSH =          2,
    DKGRAY_BRUSH =        3,
    BLACK_BRUSH =         4,
    NULL_BRUSH =          5,
    HOLLOW_BRUSH =        NULL_BRUSH,
    WHITE_PEN =           6,
    BLACK_PEN =           7,
    NULL_PEN =            8,
    OEM_FIXED_FONT =      10,
    ANSI_FIXED_FONT =     11,
    ANSI_VAR_FONT =       12,
    SYSTEM_FONT =         13,
    DEVICE_DEFAULT_FONT = 14,
    DEFAULT_PALETTE =     15,
    SYSTEM_FIXED_FONT =   16,
    DEFAULT_GUI_FONT =    17,
    STOCK_LAST =          17,
}

/*
 * ShowWindow() Commands
 */
enum
{
    SW_HIDE =             0,
    SW_SHOWNORMAL =       1,
    SW_NORMAL =           1,
    SW_SHOWMINIMIZED =    2,
    SW_SHOWMAXIMIZED =    3,
    SW_MAXIMIZE =         3,
    SW_SHOWNOACTIVATE =   4,
    SW_SHOW =             5,
    SW_MINIMIZE =         6,
    SW_SHOWMINNOACTIVE =  7,
    SW_SHOWNA =           8,
    SW_RESTORE =          9,
    SW_SHOWDEFAULT =      10,
    SW_MAX =              10,
}

struct TEXTMETRICA
{
    LONG        tmHeight;
    LONG        tmAscent;
    LONG        tmDescent;
    LONG        tmInternalLeading;
    LONG        tmExternalLeading;
    LONG        tmAveCharWidth;
    LONG        tmMaxCharWidth;
    LONG        tmWeight;
    LONG        tmOverhang;
    LONG        tmDigitizedAspectX;
    LONG        tmDigitizedAspectY;
    BYTE        tmFirstChar;
    BYTE        tmLastChar;
    BYTE        tmDefaultChar;
    BYTE        tmBreakChar;
    BYTE        tmItalic;
    BYTE        tmUnderlined;
    BYTE        tmStruckOut;
    BYTE        tmPitchAndFamily;
    BYTE        tmCharSet;
}

export @nogc BOOL   GetTextMetricsA(HDC, TEXTMETRICA*);

/*
 * Scroll Bar Constants
 */
enum
{
    SB_HORZ =             0,
    SB_VERT =             1,
    SB_CTL =              2,
    SB_BOTH =             3,
}

/*
 * Scroll Bar Commands
 */
enum
{
    SB_LINEUP =           0,
    SB_LINELEFT =         0,
    SB_LINEDOWN =         1,
    SB_LINERIGHT =        1,
    SB_PAGEUP =           2,
    SB_PAGELEFT =         2,
    SB_PAGEDOWN =         3,
    SB_PAGERIGHT =        3,
    SB_THUMBPOSITION =    4,
    SB_THUMBTRACK =       5,
    SB_TOP =              6,
    SB_LEFT =             6,
    SB_BOTTOM =           7,
    SB_RIGHT =            7,
    SB_ENDSCROLL =        8,
}

@nogc
{
export int SetScrollPos(HWND hWnd, int nBar, int nPos, BOOL bRedraw);
export int GetScrollPos(HWND hWnd, int nBar);
export BOOL SetScrollRange(HWND hWnd, int nBar, int nMinPos, int nMaxPos, BOOL bRedraw);
export BOOL GetScrollRange(HWND hWnd, int nBar, LPINT lpMinPos, LPINT lpMaxPos);
export BOOL ShowScrollBar(HWND hWnd, int wBar, BOOL bShow);
export BOOL EnableScrollBar(HWND hWnd, UINT wSBflags, UINT wArrows);
}

/*
 * LockWindowUpdate API
 */

@nogc
{
export BOOL LockWindowUpdate(HWND hWndLock);
export BOOL ScrollWindow(HWND hWnd, int XAmount, int YAmount, RECT* lpRect, RECT* lpClipRect);
export BOOL ScrollDC(HDC hDC, int dx, int dy, RECT* lprcScroll, RECT* lprcClip, HRGN hrgnUpdate, LPRECT lprcUpdate);
export int ScrollWindowEx(HWND hWnd, int dx, int dy, RECT* prcScroll, RECT* prcClip, HRGN hrgnUpdate, LPRECT prcUpdate, UINT flags);
}

/*
 * Key State API
 */

@nogc
{
export SHORT GetKeyState(int vKey);
export SHORT GetAsyncKeyState(int vKey);
export BOOL GetKeyboardState(PBYTE lpKeyState);
export BOOL SetKeyboardState(LPBYTE lpKeyState);
export UINT MapVirtualKey(UINT uCode, UINT uMapType);
}

/*
 * Virtual Keys, Standard Set
 */
enum
{
    VK_LBUTTON =        0x01,
    VK_RBUTTON =        0x02,
    VK_CANCEL =         0x03,
    VK_MBUTTON =        0x04, /* NOT contiguous with L & RBUTTON */

    VK_BACK =           0x08,
    VK_TAB =            0x09,

    VK_CLEAR =          0x0C,
    VK_RETURN =         0x0D,

    VK_SHIFT =          0x10,
    VK_CONTROL =        0x11,
    VK_MENU =           0x12,
    VK_PAUSE =          0x13,
    VK_CAPITAL =        0x14,


    VK_ESCAPE =         0x1B,

    VK_SPACE =          0x20,
    VK_PRIOR =          0x21,
    VK_NEXT =           0x22,
    VK_END =            0x23,
    VK_HOME =           0x24,
    VK_LEFT =           0x25,
    VK_UP =             0x26,
    VK_RIGHT =          0x27,
    VK_DOWN =           0x28,
    VK_SELECT =         0x29,
    VK_PRINT =          0x2A,
    VK_EXECUTE =        0x2B,
    VK_SNAPSHOT =       0x2C,
    VK_INSERT =         0x2D,
    VK_DELETE =         0x2E,
    VK_HELP =           0x2F,

/* VK_0 thru VK_9 are the same as ASCII '0' thru '9' (0x30 - 0x39) */
/* VK_A thru VK_Z are the same as ASCII 'A' thru 'Z' (0x41 - 0x5A) */

    VK_LWIN =           0x5B,
    VK_RWIN =           0x5C,
    VK_APPS =           0x5D,

    VK_NUMPAD0 =        0x60,
    VK_NUMPAD1 =        0x61,
    VK_NUMPAD2 =        0x62,
    VK_NUMPAD3 =        0x63,
    VK_NUMPAD4 =        0x64,
    VK_NUMPAD5 =        0x65,
    VK_NUMPAD6 =        0x66,
    VK_NUMPAD7 =        0x67,
    VK_NUMPAD8 =        0x68,
    VK_NUMPAD9 =        0x69,
    VK_MULTIPLY =       0x6A,
    VK_ADD =            0x6B,
    VK_SEPARATOR =      0x6C,
    VK_SUBTRACT =       0x6D,
    VK_DECIMAL =        0x6E,
    VK_DIVIDE =         0x6F,
    VK_F1 =             0x70,
    VK_F2 =             0x71,
    VK_F3 =             0x72,
    VK_F4 =             0x73,
    VK_F5 =             0x74,
    VK_F6 =             0x75,
    VK_F7 =             0x76,
    VK_F8 =             0x77,
    VK_F9 =             0x78,
    VK_F10 =            0x79,
    VK_F11 =            0x7A,
    VK_F12 =            0x7B,
    VK_F13 =            0x7C,
    VK_F14 =            0x7D,
    VK_F15 =            0x7E,
    VK_F16 =            0x7F,
    VK_F17 =            0x80,
    VK_F18 =            0x81,
    VK_F19 =            0x82,
    VK_F20 =            0x83,
    VK_F21 =            0x84,
    VK_F22 =            0x85,
    VK_F23 =            0x86,
    VK_F24 =            0x87,

    VK_NUMLOCK =        0x90,
    VK_SCROLL =         0x91,

/*
 * VK_L* & VK_R* - left and right Alt, Ctrl and Shift virtual keys.
 * Used only as parameters to GetAsyncKeyState() and GetKeyState().
 * No other API or message will distinguish left and right keys in this way.
 */
    VK_LSHIFT =         0xA0,
    VK_RSHIFT =         0xA1,
    VK_LCONTROL =       0xA2,
    VK_RCONTROL =       0xA3,
    VK_LMENU =          0xA4,
    VK_RMENU =          0xA5,


    VK_PROCESSKEY =     0xE5,


    VK_ATTN =           0xF6,
    VK_CRSEL =          0xF7,
    VK_EXSEL =          0xF8,
    VK_EREOF =          0xF9,
    VK_PLAY =           0xFA,
    VK_ZOOM =           0xFB,
    VK_NONAME =         0xFC,
    VK_PA1 =            0xFD,
    VK_OEM_CLEAR =      0xFE,
}

export @nogc LRESULT SendMessageA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);

alias UINT function (HWND, UINT, WPARAM, LPARAM) LPOFNHOOKPROC;

struct OPENFILENAMEA {
   DWORD        lStructSize;
   HWND         hwndOwner;
   HINSTANCE    hInstance;
   LPCSTR       lpstrFilter;
   LPSTR        lpstrCustomFilter;
   DWORD        nMaxCustFilter;
   DWORD        nFilterIndex;
   LPSTR        lpstrFile;
   DWORD        nMaxFile;
   LPSTR        lpstrFileTitle;
   DWORD        nMaxFileTitle;
   LPCSTR       lpstrInitialDir;
   LPCSTR       lpstrTitle;
   DWORD        Flags;
   WORD         nFileOffset;
   WORD         nFileExtension;
   LPCSTR       lpstrDefExt;
   LPARAM       lCustData;
   LPOFNHOOKPROC lpfnHook;
   LPCSTR       lpTemplateName;
}
alias OPENFILENAMEA *LPOPENFILENAMEA;

struct OPENFILENAMEW {
   DWORD        lStructSize;
   HWND         hwndOwner;
   HINSTANCE    hInstance;
   LPCWSTR      lpstrFilter;
   LPWSTR       lpstrCustomFilter;
   DWORD        nMaxCustFilter;
   DWORD        nFilterIndex;
   LPWSTR       lpstrFile;
   DWORD        nMaxFile;
   LPWSTR       lpstrFileTitle;
   DWORD        nMaxFileTitle;
   LPCWSTR      lpstrInitialDir;
   LPCWSTR      lpstrTitle;
   DWORD        Flags;
   WORD         nFileOffset;
   WORD         nFileExtension;
   LPCWSTR      lpstrDefExt;
   LPARAM       lCustData;
   LPOFNHOOKPROC lpfnHook;
   LPCWSTR      lpTemplateName;
}
alias OPENFILENAMEW *LPOPENFILENAMEW;

@nogc
{
BOOL          GetOpenFileNameA(LPOPENFILENAMEA);
BOOL          GetOpenFileNameW(LPOPENFILENAMEW);

BOOL          GetSaveFileNameA(LPOPENFILENAMEA);
BOOL          GetSaveFileNameW(LPOPENFILENAMEW);

short         GetFileTitleA(LPCSTR, LPSTR, WORD);
short         GetFileTitleW(LPCWSTR, LPWSTR, WORD);
}

enum
{
    PM_NOREMOVE =         0x0000,
    PM_REMOVE =           0x0001,
    PM_NOYIELD =          0x0002,
}

/* Bitmap Header Definition */
struct BITMAP
{
    LONG        bmType;
    LONG        bmWidth;
    LONG        bmHeight;
    LONG        bmWidthBytes;
    WORD        bmPlanes;
    WORD        bmBitsPixel;
    LPVOID      bmBits;
}
alias BITMAP* PBITMAP, NPBITMAP, LPBITMAP;

@nogc
{
export  HDC       CreateCompatibleDC(HDC);

export  int     GetObjectA(HGDIOBJ, int, LPVOID);
export  int     GetObjectW(HGDIOBJ, int, LPVOID);
export  BOOL   DeleteDC(HDC);
}

struct LOGFONTA
{
    LONG      lfHeight;
    LONG      lfWidth;
    LONG      lfEscapement;
    LONG      lfOrientation;
    LONG      lfWeight;
    BYTE      lfItalic;
    BYTE      lfUnderline;
    BYTE      lfStrikeOut;
    BYTE      lfCharSet;
    BYTE      lfOutPrecision;
    BYTE      lfClipPrecision;
    BYTE      lfQuality;
    BYTE      lfPitchAndFamily;
    CHAR[32]  lfFaceName;
}
alias LOGFONTA* PLOGFONTA, NPLOGFONTA, LPLOGFONTA;

@nogc
{
export HMENU LoadMenuA(HINSTANCE hInstance, LPCSTR lpMenuName);
export HMENU LoadMenuW(HINSTANCE hInstance, LPCWSTR lpMenuName);

export HMENU GetSubMenu(HMENU hMenu, int nPos);

export HBITMAP LoadBitmapA(HINSTANCE hInstance, LPCSTR lpBitmapName);
export HBITMAP LoadBitmapW(HINSTANCE hInstance, LPCWSTR lpBitmapName);

LPSTR MAKEINTRESOURCEA(int i) { return cast(LPSTR)(cast(DWORD)(cast(WORD)(i))); }

export  HFONT     CreateFontIndirectA(LOGFONTA *);

export BOOL MessageBeep(UINT uType);
export int ShowCursor(BOOL bShow);
export BOOL SetCursorPos(int X, int Y);
export HCURSOR SetCursor(HCURSOR hCursor);
export BOOL GetCursorPos(LPPOINT lpPoint);
export BOOL ClipCursor( RECT *lpRect);
export BOOL GetClipCursor(LPRECT lpRect);
export HCURSOR GetCursor();
export BOOL CreateCaret(HWND hWnd, HBITMAP hBitmap , int nWidth, int nHeight);
export UINT GetCaretBlinkTime();
export BOOL SetCaretBlinkTime(UINT uMSeconds);
export BOOL DestroyCaret();
export BOOL HideCaret(HWND hWnd);
export BOOL ShowCaret(HWND hWnd);
export BOOL SetCaretPos(int X, int Y);
export BOOL GetCaretPos(LPPOINT lpPoint);
export BOOL ClientToScreen(HWND hWnd, LPPOINT lpPoint);
export BOOL ScreenToClient(HWND hWnd, LPPOINT lpPoint);
export int MapWindowPoints(HWND hWndFrom, HWND hWndTo, LPPOINT lpPoints, UINT cPoints);
export HWND WindowFromPoint(POINT Point);
export HWND ChildWindowFromPoint(HWND hWndParent, POINT Point);


export BOOL TrackPopupMenu(HMENU hMenu, UINT uFlags, int x, int y,
    int nReserved, HWND hWnd, RECT *prcRect);
}

align (2) struct DLGTEMPLATE {
    DWORD style;
    DWORD dwExtendedStyle;
    WORD cdit;
    short x;
    short y;
    short cx;
    short cy;
}
alias DLGTEMPLATE *LPDLGTEMPLATEA;
alias DLGTEMPLATE *LPDLGTEMPLATEW;


alias LPDLGTEMPLATEA LPDLGTEMPLATE;

alias  DLGTEMPLATE *LPCDLGTEMPLATEA;
alias  DLGTEMPLATE *LPCDLGTEMPLATEW;


alias LPCDLGTEMPLATEA LPCDLGTEMPLATE;


export @nogc int DialogBoxParamA(HINSTANCE hInstance, LPCSTR lpTemplateName,
    HWND hWndParent, DLGPROC lpDialogFunc, LPARAM dwInitParam);
export @nogc int DialogBoxIndirectParamA(HINSTANCE hInstance,
    LPCDLGTEMPLATEA hDialogTemplate, HWND hWndParent, DLGPROC lpDialogFunc,
    LPARAM dwInitParam);

enum : DWORD
{
    SRCCOPY =             cast(DWORD)0x00CC0020, /* dest = source                   */
    SRCPAINT =            cast(DWORD)0x00EE0086, /* dest = source OR dest           */
    SRCAND =              cast(DWORD)0x008800C6, /* dest = source AND dest          */
    SRCINVERT =           cast(DWORD)0x00660046, /* dest = source XOR dest          */
    SRCERASE =            cast(DWORD)0x00440328, /* dest = source AND (NOT dest)   */
    NOTSRCCOPY =          cast(DWORD)0x00330008, /* dest = (NOT source)             */
    NOTSRCERASE =         cast(DWORD)0x001100A6, /* dest = (NOT src) AND (NOT dest) */
    MERGECOPY =           cast(DWORD)0x00C000CA, /* dest = (source AND pattern)     */
    MERGEPAINT =          cast(DWORD)0x00BB0226, /* dest = (NOT source) OR dest     */
    PATCOPY =             cast(DWORD)0x00F00021, /* dest = pattern                  */
    PATPAINT =            cast(DWORD)0x00FB0A09, /* dest = DPSnoo                   */
    PATINVERT =           cast(DWORD)0x005A0049, /* dest = pattern XOR dest         */
    DSTINVERT =           cast(DWORD)0x00550009, /* dest = (NOT dest)               */
    BLACKNESS =           cast(DWORD)0x00000042, /* dest = BLACK                    */
    WHITENESS =           cast(DWORD)0x00FF0062, /* dest = WHITE                    */
}

enum
{
    SND_SYNC =            0x0000, /* play synchronously (default) */
    SND_ASYNC =           0x0001, /* play asynchronously */
    SND_NODEFAULT =       0x0002, /* silence (!default) if sound not found */
    SND_MEMORY =          0x0004, /* pszSound points to a memory file */
    SND_LOOP =            0x0008, /* loop the sound until next sndPlaySound */
    SND_NOSTOP =          0x0010, /* don't stop any currently playing sound */

    SND_NOWAIT =    0x00002000, /* don't wait if the driver is busy */
    SND_ALIAS =       0x00010000, /* name is a registry alias */
    SND_ALIAS_ID =  0x00110000, /* alias is a predefined ID */
    SND_FILENAME =    0x00020000, /* name is file name */
    SND_RESOURCE =    0x00040004, /* name is resource name or atom */

    SND_PURGE =           0x0040, /* purge non-static events for task */
    SND_APPLICATION =     0x0080, /* look for application specific association */


    SND_ALIAS_START =   0,     /* alias base */
}

@nogc
{
export  BOOL   PlaySoundA(LPCSTR pszSound, HMODULE hmod, DWORD fdwSound);
export  BOOL   PlaySoundW(LPCWSTR pszSound, HMODULE hmod, DWORD fdwSound);

export  int     GetClipBox(HDC, LPRECT);
export  int     GetClipRgn(HDC, HRGN);
export  int     GetMetaRgn(HDC, HRGN);
export  HGDIOBJ   GetCurrentObject(HDC, UINT);
export  BOOL    GetCurrentPositionEx(HDC, LPPOINT);
export  int     GetDeviceCaps(HDC, int);
}

struct LOGPEN
{
    UINT        lopnStyle;
    POINT       lopnWidth;
    COLORREF    lopnColor;
}
alias LOGPEN* PLOGPEN, NPLOGPEN, LPLOGPEN;

enum
{
    PS_SOLID =            0,
    PS_DASH =             1, /* -------  */
    PS_DOT =              2, /* .......  */
    PS_DASHDOT =          3, /* _._._._  */
    PS_DASHDOTDOT =       4, /* _.._.._  */
    PS_NULL =             5,
    PS_INSIDEFRAME =      6,
    PS_USERSTYLE =        7,
    PS_ALTERNATE =        8,
    PS_STYLE_MASK =       0x0000000F,

    PS_ENDCAP_ROUND =     0x00000000,
    PS_ENDCAP_SQUARE =    0x00000100,
    PS_ENDCAP_FLAT =      0x00000200,
    PS_ENDCAP_MASK =      0x00000F00,

    PS_JOIN_ROUND =       0x00000000,
    PS_JOIN_BEVEL =       0x00001000,
    PS_JOIN_MITER =       0x00002000,
    PS_JOIN_MASK =        0x0000F000,

    PS_COSMETIC =         0x00000000,
    PS_GEOMETRIC =        0x00010000,
    PS_TYPE_MASK =        0x000F0000,
}

@nogc
{
export  HPALETTE   CreatePalette(LOGPALETTE *);
export  HPEN      CreatePen(int, int, COLORREF);
export  HPEN      CreatePenIndirect(LOGPEN *);
export  HRGN      CreatePolyPolygonRgn(POINT *, INT *, int, int);
export  HBRUSH    CreatePatternBrush(HBITMAP);
export  HRGN      CreateRectRgn(int, int, int, int);
export  HRGN      CreateRectRgnIndirect(RECT *);
export  HRGN      CreateRoundRectRgn(int, int, int, int, int, int);
export  BOOL      CreateScalableFontResourceA(DWORD, LPCSTR, LPCSTR, LPCSTR);
export  BOOL      CreateScalableFontResourceW(DWORD, LPCWSTR, LPCWSTR, LPCWSTR);

COLORREF RGB(int r, int g, int b)
{
    return cast(COLORREF)
    ((cast(BYTE)r|(cast(WORD)(cast(BYTE)g)<<8))|((cast(DWORD)cast(BYTE)b)<<16));
}

export  BOOL   LineTo(HDC, int, int);
export  BOOL   DeleteObject(HGDIOBJ);
export int FillRect(HDC hDC,  RECT *lprc, HBRUSH hbr);


export BOOL EndDialog(HWND hDlg, int nResult);
export HWND GetDlgItem(HWND hDlg, int nIDDlgItem);

export BOOL SetDlgItemInt(HWND hDlg, int nIDDlgItem, UINT uValue, BOOL bSigned);
export UINT GetDlgItemInt(HWND hDlg, int nIDDlgItem, BOOL *lpTranslated,
    BOOL bSigned);

export BOOL SetDlgItemTextA(HWND hDlg, int nIDDlgItem, LPCSTR lpString);
export BOOL SetDlgItemTextW(HWND hDlg, int nIDDlgItem, LPCWSTR lpString);

export UINT GetDlgItemTextA(HWND hDlg, int nIDDlgItem, LPSTR lpString, int nMaxCount);
export UINT GetDlgItemTextW(HWND hDlg, int nIDDlgItem, LPWSTR lpString, int nMaxCount);

export BOOL CheckDlgButton(HWND hDlg, int nIDButton, UINT uCheck);
export BOOL CheckRadioButton(HWND hDlg, int nIDFirstButton, int nIDLastButton,
    int nIDCheckButton);

export UINT IsDlgButtonChecked(HWND hDlg, int nIDButton);

export HWND SetFocus(HWND hWnd);
}

extern (C) @nogc
{
    export int wsprintfA(LPSTR, LPCSTR, ...);
    export int wsprintfW(LPWSTR, LPCWSTR, ...);
}

enum : uint
{
    INFINITE =              uint.max,
    WAIT_OBJECT_0 =         0,
    WAIT_ABANDONED_0 =      0x80,
    WAIT_TIMEOUT =          0x102,
    WAIT_IO_COMPLETION =    0xc0,
    WAIT_ABANDONED =        0x80,
    WAIT_FAILED =           uint.max,
}

@nogc
{
export HANDLE CreateSemaphoreA(LPSECURITY_ATTRIBUTES lpSemaphoreAttributes, LONG lInitialCount, LONG lMaximumCount, LPCTSTR lpName) @trusted;
export HANDLE OpenSemaphoreA(DWORD dwDesiredAccess, BOOL bInheritHandle, LPCTSTR lpName);
export BOOL ReleaseSemaphore(HANDLE hSemaphore, LONG lReleaseCount, LPLONG lpPreviousCount);
}

struct COORD {
    SHORT X;
    SHORT Y;
}
alias COORD *PCOORD;

struct SMALL_RECT {
    SHORT Left;
    SHORT Top;
    SHORT Right;
    SHORT Bottom;
}
alias SMALL_RECT *PSMALL_RECT;

struct KEY_EVENT_RECORD {
    BOOL bKeyDown;
    WORD wRepeatCount;
    WORD wVirtualKeyCode;
    WORD wVirtualScanCode;
    union {
        WCHAR UnicodeChar;
        CHAR   AsciiChar;
    }
    DWORD dwControlKeyState;
}
alias KEY_EVENT_RECORD *PKEY_EVENT_RECORD;

//
// ControlKeyState flags
//

enum
{
    RIGHT_ALT_PRESSED =     0x0001, // the right alt key is pressed.
    LEFT_ALT_PRESSED =      0x0002, // the left alt key is pressed.
    RIGHT_CTRL_PRESSED =    0x0004, // the right ctrl key is pressed.
    LEFT_CTRL_PRESSED =     0x0008, // the left ctrl key is pressed.
    SHIFT_PRESSED =         0x0010, // the shift key is pressed.
    NUMLOCK_ON =            0x0020, // the numlock light is on.
    SCROLLLOCK_ON =         0x0040, // the scrolllock light is on.
    CAPSLOCK_ON =           0x0080, // the capslock light is on.
    ENHANCED_KEY =          0x0100, // the key is enhanced.
}

struct MOUSE_EVENT_RECORD {
    COORD dwMousePosition;
    DWORD dwButtonState;
    DWORD dwControlKeyState;
    DWORD dwEventFlags;
}
alias MOUSE_EVENT_RECORD *PMOUSE_EVENT_RECORD;

//
// ButtonState flags
//
enum
{
    FROM_LEFT_1ST_BUTTON_PRESSED =    0x0001,
    RIGHTMOST_BUTTON_PRESSED =        0x0002,
    FROM_LEFT_2ND_BUTTON_PRESSED =    0x0004,
    FROM_LEFT_3RD_BUTTON_PRESSED =    0x0008,
    FROM_LEFT_4TH_BUTTON_PRESSED =    0x0010,
}

//
// EventFlags
//

enum
{
    MOUSE_MOVED =   0x0001,
    DOUBLE_CLICK =  0x0002,
}

struct WINDOW_BUFFER_SIZE_RECORD {
    COORD dwSize;
}
alias WINDOW_BUFFER_SIZE_RECORD *PWINDOW_BUFFER_SIZE_RECORD;

struct MENU_EVENT_RECORD {
    UINT dwCommandId;
}
alias MENU_EVENT_RECORD *PMENU_EVENT_RECORD;

struct FOCUS_EVENT_RECORD {
    BOOL bSetFocus;
}
alias FOCUS_EVENT_RECORD *PFOCUS_EVENT_RECORD;

struct INPUT_RECORD {
    WORD EventType;
    union {
        KEY_EVENT_RECORD KeyEvent;
        MOUSE_EVENT_RECORD MouseEvent;
        WINDOW_BUFFER_SIZE_RECORD WindowBufferSizeEvent;
        MENU_EVENT_RECORD MenuEvent;
        FOCUS_EVENT_RECORD FocusEvent;
    }
}
alias INPUT_RECORD *PINPUT_RECORD;

//
//  EventType flags:
//

enum
{
    KEY_EVENT =         0x0001, // Event contains key event record
    MOUSE_EVENT =       0x0002, // Event contains mouse event record
    WINDOW_BUFFER_SIZE_EVENT = 0x0004, // Event contains window change event record
    MENU_EVENT = 0x0008, // Event contains menu event record
    FOCUS_EVENT = 0x0010, // event contains focus change
}

struct CHAR_INFO {
    union {
        WCHAR UnicodeChar;
        CHAR   AsciiChar;
    }
    WORD Attributes;
}
alias CHAR_INFO *PCHAR_INFO;

//
// Attributes flags:
//

enum
{
    FOREGROUND_BLUE =      0x0001, // text color contains blue.
    FOREGROUND_GREEN =     0x0002, // text color contains green.
    FOREGROUND_RED =       0x0004, // text color contains red.
    FOREGROUND_INTENSITY = 0x0008, // text color is intensified.
    BACKGROUND_BLUE =      0x0010, // background color contains blue.
    BACKGROUND_GREEN =     0x0020, // background color contains green.
    BACKGROUND_RED =       0x0040, // background color contains red.
    BACKGROUND_INTENSITY = 0x0080, // background color is intensified.
}

struct CONSOLE_SCREEN_BUFFER_INFO {
    COORD dwSize;
    COORD dwCursorPosition;
    WORD  wAttributes;
    SMALL_RECT srWindow;
    COORD dwMaximumWindowSize;
}
alias CONSOLE_SCREEN_BUFFER_INFO *PCONSOLE_SCREEN_BUFFER_INFO;

struct CONSOLE_CURSOR_INFO {
    DWORD  dwSize;
    BOOL   bVisible;
}
alias CONSOLE_CURSOR_INFO *PCONSOLE_CURSOR_INFO;

enum
{
    ENABLE_PROCESSED_INPUT = 0x0001,
    ENABLE_LINE_INPUT =      0x0002,
    ENABLE_ECHO_INPUT =      0x0004,
    ENABLE_WINDOW_INPUT =    0x0008,
    ENABLE_MOUSE_INPUT =     0x0010,
}

enum
{
    ENABLE_PROCESSED_OUTPUT =    0x0001,
    ENABLE_WRAP_AT_EOL_OUTPUT =  0x0002,
}

@nogc
{
BOOL PeekConsoleInputA(HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
BOOL PeekConsoleInputW(HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
BOOL ReadConsoleInputA(HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
BOOL ReadConsoleInputW(HANDLE hConsoleInput, PINPUT_RECORD lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsRead);
BOOL WriteConsoleInputA(HANDLE hConsoleInput, in INPUT_RECORD *lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsWritten);
BOOL WriteConsoleInputW(HANDLE hConsoleInput, in INPUT_RECORD *lpBuffer, DWORD nLength, LPDWORD lpNumberOfEventsWritten);
BOOL ReadConsoleOutputA(HANDLE hConsoleOutput, PCHAR_INFO lpBuffer, COORD dwBufferSize, COORD dwBufferCoord, PSMALL_RECT lpReadRegion);
BOOL ReadConsoleOutputW(HANDLE hConsoleOutput, PCHAR_INFO lpBuffer, COORD dwBufferSize, COORD dwBufferCoord, PSMALL_RECT lpReadRegion);
BOOL WriteConsoleOutputA(HANDLE hConsoleOutput, in CHAR_INFO *lpBuffer, COORD dwBufferSize, COORD dwBufferCoord, PSMALL_RECT lpWriteRegion);
BOOL WriteConsoleOutputW(HANDLE hConsoleOutput, in CHAR_INFO *lpBuffer, COORD dwBufferSize, COORD dwBufferCoord, PSMALL_RECT lpWriteRegion);
BOOL ReadConsoleOutputCharacterA(HANDLE hConsoleOutput, LPSTR lpCharacter, DWORD nLength, COORD dwReadCoord, LPDWORD lpNumberOfCharsRead);
BOOL ReadConsoleOutputCharacterW(HANDLE hConsoleOutput, LPWSTR lpCharacter, DWORD nLength, COORD dwReadCoord, LPDWORD lpNumberOfCharsRead);
BOOL ReadConsoleOutputAttribute(HANDLE hConsoleOutput, LPWORD lpAttribute, DWORD nLength, COORD dwReadCoord, LPDWORD lpNumberOfAttrsRead);
BOOL WriteConsoleOutputCharacterA(HANDLE hConsoleOutput, LPCSTR lpCharacter, DWORD nLength, COORD dwWriteCoord, LPDWORD lpNumberOfCharsWritten);
BOOL WriteConsoleOutputCharacterW(HANDLE hConsoleOutput, LPCWSTR lpCharacter, DWORD nLength, COORD dwWriteCoord, LPDWORD lpNumberOfCharsWritten);
BOOL WriteConsoleOutputAttribute(HANDLE hConsoleOutput, in WORD *lpAttribute, DWORD nLength, COORD dwWriteCoord, LPDWORD lpNumberOfAttrsWritten);
BOOL FillConsoleOutputCharacterA(HANDLE hConsoleOutput, CHAR cCharacter, DWORD  nLength, COORD  dwWriteCoord, LPDWORD lpNumberOfCharsWritten);
BOOL FillConsoleOutputCharacterW(HANDLE hConsoleOutput, WCHAR cCharacter, DWORD  nLength, COORD  dwWriteCoord, LPDWORD lpNumberOfCharsWritten);
BOOL FillConsoleOutputAttribute(HANDLE hConsoleOutput, WORD   wAttribute, DWORD  nLength, COORD  dwWriteCoord, LPDWORD lpNumberOfAttrsWritten);
BOOL GetConsoleMode(HANDLE hConsoleHandle, LPDWORD lpMode);
BOOL GetNumberOfConsoleInputEvents(HANDLE hConsoleInput, LPDWORD lpNumberOfEvents);
BOOL GetConsoleScreenBufferInfo(HANDLE hConsoleOutput, PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);
COORD GetLargestConsoleWindowSize( HANDLE hConsoleOutput);
BOOL GetConsoleCursorInfo(HANDLE hConsoleOutput, PCONSOLE_CURSOR_INFO lpConsoleCursorInfo);
BOOL GetNumberOfConsoleMouseButtons( LPDWORD lpNumberOfMouseButtons);
BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
BOOL SetConsoleActiveScreenBuffer(HANDLE hConsoleOutput);
BOOL FlushConsoleInputBuffer(HANDLE hConsoleInput);
BOOL SetConsoleScreenBufferSize(HANDLE hConsoleOutput, COORD dwSize);
BOOL SetConsoleCursorPosition(HANDLE hConsoleOutput, COORD dwCursorPosition);
BOOL SetConsoleCursorInfo(HANDLE hConsoleOutput, in CONSOLE_CURSOR_INFO *lpConsoleCursorInfo);
BOOL ScrollConsoleScreenBufferA(HANDLE hConsoleOutput, in SMALL_RECT *lpScrollRectangle, in SMALL_RECT *lpClipRectangle, COORD dwDestinationOrigin, in CHAR_INFO *lpFill);
BOOL ScrollConsoleScreenBufferW(HANDLE hConsoleOutput, in SMALL_RECT *lpScrollRectangle, in SMALL_RECT *lpClipRectangle, COORD dwDestinationOrigin, in CHAR_INFO *lpFill);
BOOL SetConsoleWindowInfo(HANDLE hConsoleOutput, BOOL bAbsolute, in SMALL_RECT *lpConsoleWindow);
BOOL SetConsoleTextAttribute(HANDLE hConsoleOutput, WORD wAttributes);
BOOL SetConsoleCtrlHandler(PHANDLER_ROUTINE HandlerRoutine, BOOL Add);
BOOL GenerateConsoleCtrlEvent( DWORD dwCtrlEvent, DWORD dwProcessGroupId);
BOOL AllocConsole();
BOOL FreeConsole();
DWORD GetConsoleTitleA(LPSTR lpConsoleTitle, DWORD nSize);
DWORD GetConsoleTitleW(LPWSTR lpConsoleTitle, DWORD nSize);
BOOL SetConsoleTitleA(LPCSTR lpConsoleTitle);
BOOL SetConsoleTitleW(LPCWSTR lpConsoleTitle);
BOOL ReadConsoleA(HANDLE hConsoleInput, LPVOID lpBuffer, DWORD nNumberOfCharsToRead, LPDWORD lpNumberOfCharsRead, LPVOID lpReserved);
BOOL ReadConsoleW(HANDLE hConsoleInput, LPVOID lpBuffer, DWORD nNumberOfCharsToRead, LPDWORD lpNumberOfCharsRead, LPVOID lpReserved);
BOOL WriteConsoleA(HANDLE hConsoleOutput, in  void *lpBuffer, DWORD nNumberOfCharsToWrite, LPDWORD lpNumberOfCharsWritten, LPVOID lpReserved);
BOOL WriteConsoleW(HANDLE hConsoleOutput, in  void *lpBuffer, DWORD nNumberOfCharsToWrite, LPDWORD lpNumberOfCharsWritten, LPVOID lpReserved);
HANDLE CreateConsoleScreenBuffer(DWORD dwDesiredAccess, DWORD dwShareMode, in SECURITY_ATTRIBUTES *lpSecurityAttributes, DWORD dwFlags, LPVOID lpScreenBufferData);
UINT GetConsoleCP();
BOOL SetConsoleCP( UINT wCodePageID);
UINT GetConsoleOutputCP();
BOOL SetConsoleOutputCP(UINT wCodePageID);
}

alias BOOL function(DWORD CtrlType) PHANDLER_ROUTINE;

enum
{
    CONSOLE_TEXTMODE_BUFFER = 1,
}

enum
{
    SM_CXSCREEN =             0,
    SM_CYSCREEN =             1,
    SM_CXVSCROLL =            2,
    SM_CYHSCROLL =            3,
    SM_CYCAPTION =            4,
    SM_CXBORDER =             5,
    SM_CYBORDER =             6,
    SM_CXDLGFRAME =           7,
    SM_CYDLGFRAME =           8,
    SM_CYVTHUMB =             9,
    SM_CXHTHUMB =             10,
    SM_CXICON =               11,
    SM_CYICON =               12,
    SM_CXCURSOR =             13,
    SM_CYCURSOR =             14,
    SM_CYMENU =               15,
    SM_CXFULLSCREEN =         16,
    SM_CYFULLSCREEN =         17,
    SM_CYKANJIWINDOW =        18,
    SM_MOUSEPRESENT =         19,
    SM_CYVSCROLL =            20,
    SM_CXHSCROLL =            21,
    SM_DEBUG =                22,
    SM_SWAPBUTTON =           23,
    SM_RESERVED1 =            24,
    SM_RESERVED2 =            25,
    SM_RESERVED3 =            26,
    SM_RESERVED4 =            27,
    SM_CXMIN =                28,
    SM_CYMIN =                29,
    SM_CXSIZE =               30,
    SM_CYSIZE =               31,
    SM_CXFRAME =              32,
    SM_CYFRAME =              33,
    SM_CXMINTRACK =           34,
    SM_CYMINTRACK =           35,
    SM_CXDOUBLECLK =          36,
    SM_CYDOUBLECLK =          37,
    SM_CXICONSPACING =        38,
    SM_CYICONSPACING =        39,
    SM_MENUDROPALIGNMENT =    40,
    SM_PENWINDOWS =           41,
    SM_DBCSENABLED =          42,
    SM_CMOUSEBUTTONS =        43,


    SM_CXFIXEDFRAME =         SM_CXDLGFRAME,
    SM_CYFIXEDFRAME =         SM_CYDLGFRAME,
    SM_CXSIZEFRAME =          SM_CXFRAME,
    SM_CYSIZEFRAME =          SM_CYFRAME,

    SM_SECURE =               44,
    SM_CXEDGE =               45,
    SM_CYEDGE =               46,
    SM_CXMINSPACING =         47,
    SM_CYMINSPACING =         48,
    SM_CXSMICON =             49,
    SM_CYSMICON =             50,
    SM_CYSMCAPTION =          51,
    SM_CXSMSIZE =             52,
    SM_CYSMSIZE =             53,
    SM_CXMENUSIZE =           54,
    SM_CYMENUSIZE =           55,
    SM_ARRANGE =              56,
    SM_CXMINIMIZED =          57,
    SM_CYMINIMIZED =          58,
    SM_CXMAXTRACK =           59,
    SM_CYMAXTRACK =           60,
    SM_CXMAXIMIZED =          61,
    SM_CYMAXIMIZED =          62,
    SM_NETWORK =              63,
    SM_CLEANBOOT =            67,
    SM_CXDRAG =               68,
    SM_CYDRAG =               69,
    SM_SHOWSOUNDS =           70,
    SM_CXMENUCHECK =          71,
    SM_CYMENUCHECK =          72,
    SM_SLOWMACHINE =          73,
    SM_MIDEASTENABLED =       74,
    SM_CMETRICS =             75,
}

@nogc
int GetSystemMetrics(int nIndex);

enum : DWORD
{
    STILL_ACTIVE = (0x103),
}

@nogc
{
DWORD TlsAlloc();
LPVOID TlsGetValue(DWORD);
BOOL TlsSetValue(DWORD, LPVOID);
BOOL TlsFree(DWORD);
}

struct STARTUPINFO
{
    DWORD  cb = STARTUPINFO.sizeof;
    LPSTR  lpReserved;
    LPSTR  lpDesktop;
    LPSTR  lpTitle;
    DWORD  dwX;
    DWORD  dwY;
    DWORD  dwXSize;
    DWORD  dwYSize;
    DWORD  dwXCountChars;
    DWORD  dwYCountChars;
    DWORD  dwFillAttribute;
    DWORD  dwFlags;
    WORD   wShowWindow;
    WORD   cbReserved2;
    LPBYTE lpReserved2;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
}

struct STARTUPINFO_W
{
    DWORD  cb = STARTUPINFO_W.sizeof;
    LPWSTR lpReserved;
    LPWSTR lpDesktop;
    LPWSTR lpTitle;
    DWORD  dwX;
    DWORD  dwY;
    DWORD  dwXSize;
    DWORD  dwYSize;
    DWORD  dwXCountChars;
    DWORD  dwYCountChars;
    DWORD  dwFillAttribute;
    DWORD  dwFlags;
    WORD   wShowWindow;
    WORD   cbReserved2;
    LPBYTE lpReserved2;
    HANDLE hStdInput;
    HANDLE hStdOutput;
    HANDLE hStdError;
}

alias STARTUPINFO *LPSTARTUPINFO;
alias STARTUPINFO_W *LPSTARTUPINFO_W;

struct PROCESS_INFORMATION
{
    HANDLE hProcess;
    HANDLE hThread;
    DWORD  dwProcessId;
    DWORD  dwThreadId;
}

alias PROCESS_INFORMATION *LPPROCESS_INFORMATION;

export @nogc
{
    BOOL CreateProcessA(LPCSTR lpApplicationName, LPSTR lpCommandLine,
        LPSECURITY_ATTRIBUTES lpProcessAttributes,
        LPSECURITY_ATTRIBUTES lpThreadAttributes, BOOL bInheritHandles,
        DWORD dwCreationFlags, LPVOID lpEnvironment, LPCSTR lpCurrentDirectory,
        LPSTARTUPINFO lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);

    BOOL CreateProcessW(LPCWSTR lpApplicationName, LPWSTR lpCommandLine,
        LPSECURITY_ATTRIBUTES lpProcessAttributes,
        LPSECURITY_ATTRIBUTES lpThreadAttributes, BOOL bInheritHandles,
        DWORD dwCreationFlags, LPVOID lpEnvironment, LPCWSTR lpCurrentDirectory,
        LPSTARTUPINFO_W lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);

    BOOL CreatePipe(PHANDLE hReadPipe, PHANDLE hWritePipe,
        LPSECURITY_ATTRIBUTES lpPipeAttributes, DWORD nSize);
}

enum
{
    STARTF_USESTDHANDLES = 0x00000100
}

enum
{
    CREATE_NO_WINDOW = 0x08000000
}

// shellapi.h

@nogc
{
HINSTANCE ShellExecuteA(HWND hwnd, LPCSTR lpOperation, LPCSTR lpFile, LPCSTR lpParameters, LPCSTR lpDirectory, INT nShowCmd);
HINSTANCE ShellExecuteW(HWND hwnd, LPCWSTR lpOperation, LPCWSTR lpFile, LPCWSTR lpParameters, LPCWSTR lpDirectory, INT nShowCmd);

UINT_PTR SetTimer(HWND hwnd, UINT_PTR nIDEvent, UINT uElapse, TIMERPROC lpTimerFunc);
BOOL KillTimer(HWND hwnd, UINT_PTR nIDEvent);

BOOL GetHandleInformation(HANDLE hObject, LPDWORD lpdwFlags);
BOOL SetHandleInformation(HANDLE hObject, DWORD dwMask, DWORD dwFlags);
BOOL TerminateProcess(HANDLE hProcess, UINT uExitCode);
LPWSTR* CommandLineToArgvW(LPCWSTR lpCmdLine, int* pNumArgs);
LPWSTR GetCommandLineW();
}

enum
{
    HANDLE_FLAG_INHERIT = 0x1,
    HANDLE_FLAG_PROTECT_FROM_CLOSE = 0x2,
}

enum CREATE_UNICODE_ENVIRONMENT = 0x400;

@nogc
{
BOOL LockFile(HANDLE hFile, DWORD dwFileOffsetLow, DWORD dwFileOffsetHigh, DWORD nNumberOfBytesToLockLow, DWORD nNumberOfBytesToLockHigh);
BOOL UnlockFile(HANDLE hFile, DWORD dwFileOffsetLow, DWORD dwFileOffsetHigh, DWORD nNumberOfBytesToUnlockLow, DWORD nNumberOfBytesToUnlockHigh);
BOOL LockFileEx(HANDLE hFile, DWORD dwFlags, DWORD dwReserved, DWORD nNumberOfBytesToLockLow, DWORD nNumberOfBytesToLockHigh, LPOVERLAPPED lpOverlapped);
BOOL UnlockFileEx(HANDLE hFile, DWORD dwReserved, DWORD nNumberOfBytesToUnlockLow, DWORD nNumberOfBytesToUnlockHigh, LPOVERLAPPED lpOverlapped);
BOOL FlushFileBuffers(HANDLE hFile);
}

enum LOCKFILE_FAIL_IMMEDIATELY = 1;
enum LOCKFILE_EXCLUSIVE_LOCK   = 2;

@nogc
{
BOOL IsDebuggerPresent();

LPSTR lstrcatA(LPSTR lpString1, LPCSTR lpString2);
LPWSTR lstrcatW(LPWSTR lpString1, LPCWSTR lpString2);

int lstrcmpA(LPCSTR lpString1, LPCSTR lpString2);
int lstrcmpW(LPCWSTR lpString1,LPCWSTR lpString2);

int lstrcmpiA(LPCSTR lpString1, LPCSTR lpString2);
int lstrcmpiW(LPCWSTR lpString1,LPCWSTR lpString2);

LPSTR lstrcpyA(LPSTR lpString1, LPCSTR lpString2);
LPWSTR lstrcpyW(LPWSTR lpString1, LPCWSTR lpString2);

LPSTR lstrcpynA(LPSTR lpString1, LPCSTR lpString2, int iMaxLength);
LPWSTR lstrcpynW(LPWSTR lpString1, LPCWSTR lpString2, int iMaxLength);

int lstrlenA(LPCSTR lpString);
int lstrlenW(LPCWSTR lpString);
}

enum
{
    _S_IREAD  = 0x0100, // read permission, owner
    _S_IWRITE = 0x0080, // write permission, owner
}

enum
{
    _SH_DENYRW = 0x10, // deny read/write mode
    _SH_DENYWR = 0x20, // deny write mode
    _SH_DENYRD = 0x30, // deny read mode
    _SH_DENYNO = 0x40, // deny none mode
}

extern(C) @nogc
{
    int _wsopen(const wchar* filename, int oflag, int shflag, ...);
}
