/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_tlhelp32.d)
 */
module core.sys.windows.tlhelp32;
version (Windows):
pragma(lib, "kernel32");

version (ANSI) {} else version = Unicode;

import core.sys.windows.windef;

enum : uint {
    HF32_DEFAULT = 1,
    HF32_SHARED
}

enum : uint {
    LF32_FIXED    = 0x1,
    LF32_FREE     = 0x2,
    LF32_MOVEABLE = 0x4
}

enum MAX_MODULE_NAME32 = 255;

enum : uint {
    TH32CS_SNAPHEAPLIST = 0x1,
    TH32CS_SNAPPROCESS  = 0x2,
    TH32CS_SNAPTHREAD   = 0x4,
    TH32CS_SNAPMODULE   = 0x8,
    TH32CS_SNAPALL      = (TH32CS_SNAPHEAPLIST|TH32CS_SNAPPROCESS|TH32CS_SNAPTHREAD|TH32CS_SNAPMODULE),
    TH32CS_INHERIT      = 0x80000000
}

struct HEAPLIST32 {
    SIZE_T dwSize;
    DWORD th32ProcessID;
    ULONG_PTR th32HeapID;
    DWORD dwFlags;
}
alias PHEAPLIST32 = HEAPLIST32*;
alias LPHEAPLIST32 = HEAPLIST32*;

struct HEAPENTRY32 {
    SIZE_T dwSize;
    HANDLE hHandle;
    ULONG_PTR dwAddress;
    SIZE_T dwBlockSize;
    DWORD dwFlags;
    DWORD dwLockCount;
    DWORD dwResvd;
    DWORD th32ProcessID;
    ULONG_PTR th32HeapID;
}
alias PHEAPENTRY32 = HEAPENTRY32*;
alias LPHEAPENTRY32 = HEAPENTRY32*;

struct PROCESSENTRY32W {
    DWORD dwSize;
    DWORD cntUsage;
    DWORD th32ProcessID;
    ULONG_PTR th32DefaultHeapID;
    DWORD th32ModuleID;
    DWORD cntThreads;
    DWORD th32ParentProcessID;
    LONG pcPriClassBase;
    DWORD dwFlags;
    WCHAR[MAX_PATH] szExeFile = 0;
}
alias PPROCESSENTRY32W = PROCESSENTRY32W*;
alias LPPROCESSENTRY32W = PROCESSENTRY32W*;

struct THREADENTRY32 {
    DWORD dwSize;
    DWORD cntUsage;
    DWORD th32ThreadID;
    DWORD th32OwnerProcessID;
    LONG tpBasePri;
    LONG tpDeltaPri;
    DWORD dwFlags;
}
alias PTHREADENTRY32 = THREADENTRY32*;
alias LPTHREADENTRY32 = THREADENTRY32*;

struct MODULEENTRY32W {
    DWORD dwSize;
    DWORD th32ModuleID;
    DWORD th32ProcessID;
    DWORD GlblcntUsage;
    DWORD ProccntUsage;
    BYTE *modBaseAddr;
    DWORD modBaseSize;
    HMODULE hModule;
    WCHAR[MAX_MODULE_NAME32 + 1] szModule = 0;
    WCHAR[MAX_PATH] szExePath = 0;
}
alias PMODULEENTRY32W = MODULEENTRY32W*;
alias LPMODULEENTRY32W = MODULEENTRY32W*;

version (Unicode) {
    alias PROCESSENTRY32 = PROCESSENTRY32W;
    alias PPROCESSENTRY32 = PPROCESSENTRY32W;
    alias LPPROCESSENTRY32 = LPPROCESSENTRY32W;

    alias MODULEENTRY32 = MODULEENTRY32W;
    alias PMODULEENTRY32 = PMODULEENTRY32W;
    alias LPMODULEENTRY32 = LPMODULEENTRY32W;
} else {
    struct PROCESSENTRY32 {
        DWORD dwSize;
        DWORD cntUsage;
        DWORD th32ProcessID;
        ULONG_PTR th32DefaultHeapID;
        DWORD th32ModuleID;
        DWORD cntThreads;
        DWORD th32ParentProcessID;
        LONG pcPriClassBase;
        DWORD dwFlags;
        CHAR[MAX_PATH] szExeFile = 0;
    }
    alias PPROCESSENTRY32 = PROCESSENTRY32*;
    alias LPPROCESSENTRY32 = PROCESSENTRY32*;

    struct MODULEENTRY32 {
        DWORD dwSize;
        DWORD th32ModuleID;
        DWORD th32ProcessID;
        DWORD GlblcntUsage;
        DWORD ProccntUsage;
        BYTE *modBaseAddr;
        DWORD modBaseSize;
        HMODULE hModule;
        char[MAX_MODULE_NAME32 + 1] szModule = 0;
        char[MAX_PATH] szExePath = 0;
    }
    alias PMODULEENTRY32 = MODULEENTRY32*;
    alias LPMODULEENTRY32 = MODULEENTRY32*;
}


extern(Windows) nothrow @nogc {
    BOOL Heap32First(LPHEAPENTRY32,DWORD,ULONG_PTR);
    BOOL Heap32ListFirst(HANDLE,LPHEAPLIST32);
    BOOL Heap32ListNext(HANDLE,LPHEAPLIST32);
    BOOL Heap32Next(LPHEAPENTRY32);
    BOOL Thread32First(HANDLE,LPTHREADENTRY32);
    BOOL Thread32Next(HANDLE,LPTHREADENTRY32);
    BOOL Toolhelp32ReadProcessMemory(DWORD,LPCVOID,LPVOID,SIZE_T,SIZE_T*);
    HANDLE CreateToolhelp32Snapshot(DWORD,DWORD);
    BOOL Module32FirstW(HANDLE,LPMODULEENTRY32W);
    BOOL Module32NextW(HANDLE,LPMODULEENTRY32W);
    BOOL Process32FirstW(HANDLE,LPPROCESSENTRY32W);
    BOOL Process32NextW(HANDLE,LPPROCESSENTRY32W);
}

version (Unicode) {
    alias Module32First = Module32FirstW;
    alias Module32Next = Module32NextW;
    alias Process32First = Process32FirstW;
    alias Process32Next = Process32NextW;
} else {
    extern(Windows) nothrow @nogc {
        BOOL Module32First(HANDLE,LPMODULEENTRY32);
        BOOL Module32Next(HANDLE,LPMODULEENTRY32);
        BOOL Process32First(HANDLE,LPPROCESSENTRY32);
        BOOL Process32Next(HANDLE,LPPROCESSENTRY32);
    }
}
