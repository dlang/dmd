/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/os.d, backend/os.d)
 */

/*
 * Operating system specific routines.
 * Placed here to avoid cluttering
 * up code with OS files.
 */

import core.stdc.stdio;
import core.stdc.time;
import core.stdc.stdlib;
import core.stdc.string;

version (Posix)
{
    import core.stdc.errno;
    import core.sys.posix.fcntl;
    import core.sys.posix.pthread;
    import core.sys.posix.sys.stat;
    import core.sys.posix.sys.types;
    import core.sys.posix.unistd;
    //#define GetLastError() errno
}
else version (Windows)
{
    import core.sys.windows.stat;
    import core.sys.windows.winbase;
    import core.sys.windows.windef;
}

version (CRuntime_Microsoft)
    enum NEEDS_WIN32_NON_MS = false;
else version (Win32)
    enum NEEDS_WIN32_NON_MS = true;
else
    enum NEEDS_WIN32_NON_MS = false;

version (Win64)
    enum NEEDS_WIN32_NOT_WIN64 = false;
else version (Win32)
    enum NEEDS_WIN32_NOT_WIN64 = true;
else
    enum NEEDS_WIN32_NOT_WIN64 = false;


extern(C++):

nothrow:
@safe:

version (CRuntime_Microsoft)
{
    import core.stdc.stdlib;
}
//debug = printf;
version (Windows)
{
    extern(C++) void dll_printf(const char *format,...);
    alias printf = dll_printf;
}

/***********************************
 * Called when there is an error returned by the operating system.
 * This function does not return.
 */
void os_error(int line = __LINE__)
{
    version(Windows)
        debug(printf) printf("System error: %ldL\n", GetLastError());
    assert(0);
}

static if (NEEDS_WIN32_NOT_WIN64)
{

private __gshared HANDLE hHeap;

@trusted
void *globalrealloc(void *oldp,size_t newsize)
{
static if (0)
{
    void *p;

    // Initialize heap
    if (!hHeap)
    {   hHeap = HeapCreate(0,0x10000,0);
        if (!hHeap)
            os_error();
    }

    newsize = (newsize + 3) & ~3L;      // round up to dwords
    if (newsize == 0)
    {
        if (oldp && HeapFree(hHeap,0,oldp) == false)
            os_error();
        p = NULL;
    }
    else if (!oldp)
    {
        p = newsize ? HeapAlloc(hHeap,0,newsize) : null;
    }
    else
        p = HeapReAlloc(hHeap,0,oldp,newsize);
}
else static if (1)
{
    MEMORY_BASIC_INFORMATION query;
    void *p;
    BOOL bSuccess;

    if (!oldp)
        p = VirtualAlloc (null, newsize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    else
    {
        VirtualQuery (oldp, &query, query.sizeof);
        if (!newsize)
        {
            p = null;
            goto L1;
        }
        else
        {   newsize = (newsize + 0xFFFF) & ~0xFFFFL;

            if (query.RegionSize >= newsize)
                p = oldp;
            else
            {   p = VirtualAlloc(null,newsize,MEM_COMMIT | MEM_RESERVE,PAGE_READWRITE);
                if (p)
                    memcpy(p,oldp,query.RegionSize);
            L1:
                bSuccess = VirtualFree(oldp,query.RegionSize,MEM_DECOMMIT);
                if (bSuccess)
                    bSuccess = VirtualFree(oldp,0,MEM_RELEASE);
                if (!bSuccess)
                    os_error();
            }
        }
    }
}
else
{
    void *p;

    if (!oldp)
        p = cast(void *)GlobalAlloc (0, newsize);
    else if (!newsize)
    {   GlobalFree(oldp);
        p = null;
    }
    else
        p = cast(void *)GlobalReAlloc(oldp,newsize,0);
}
    debug(printf) printf("globalrealloc(oldp = %p, size = x%x) = %p\n",oldp,newsize,p);
    return p;
}

/*****************************************
 * Functions to manage allocating a single virtual address space.
 */

@trusted
void *vmem_reserve(void *ptr,uint size)
{   void *p;

version(none)
{
    p = VirtualAlloc(ptr,size,MEM_RESERVE,PAGE_READWRITE);
    debug(printf) printf("vmem_reserve(ptr = %p, size = x%lx) = %p\n",ptr,size,p);
}
else
{
    debug(printf) printf("vmem_reserve(ptr = %p, size = x%lx) = %p\n",ptr,size,p);
    p = VirtualAlloc(ptr,size,MEM_RESERVE,PAGE_READWRITE);
    if (!p)
        os_error();
}
    return p;
}

/*****************************************
 * Commit memory.
 * Returns:
 *      0       failure
 *      !=0     success
 */

@trusted
int vmem_commit(void *ptr, uint size)
{   int i;

    debug(printf) printf("vmem_commit(ptr = %p,size = x%lx)\n",ptr,size);
    i = cast(int) VirtualAlloc(ptr,size,MEM_COMMIT,PAGE_READWRITE);
    if (i == 0)
        debug(printf) printf("failed to commit\n");
    return i;
}

@trusted
void vmem_decommit(void *ptr,uint size)
{
    debug(printf) printf("vmem_decommit(ptr = %p, size = x%lx)\n",ptr,size);
    if (ptr)
    {   if (!VirtualFree(ptr, size, MEM_DECOMMIT))
            os_error();
    }
}

@trusted
void vmem_release(void *ptr, uint size)
{
    debug(printf) printf("vmem_release(ptr = %p, size = x%lx)\n",ptr,size);
    if (ptr)
    {
        if (!VirtualFree(ptr, 0, MEM_RELEASE))
            os_error();
    }
}

/********************************************
 * Map file for read, copy on write, into virtual address space.
 * Input:
 *      ptr             address to map file to, if NULL then pick an address
 *      size            length of the file
 *      flag    0       read / write
 *              1       read / copy on write
 *              2       read only
 * Returns:
 *      NULL    failure
 *      ptr     pointer to start of mapped file
 */

private __gshared HANDLE hFile = INVALID_HANDLE_VALUE;
private __gshared HANDLE hFileMap = null;
private __gshared void *pview;
private __gshared void *preserve;
private __gshared size_t preserve_size;

@trusted
void *vmem_mapfile(const char *filename,void *ptr, uint size,int flag)
{
    OSVERSIONINFO OsVerInfo;

    OsVerInfo.dwOSVersionInfoSize = OsVerInfo.sizeof;
    GetVersionEx(&OsVerInfo);

    debug(printf) printf("vmem_mapfile(filename = '%s', ptr = %p, size = x%lx, flag = %d)\n",
                         filename,ptr,size,flag);

    hFile = CreateFileA(filename, GENERIC_READ | GENERIC_WRITE,
                        FILE_SHARE_READ | FILE_SHARE_WRITE, null,
                        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
    if (hFile == INVALID_HANDLE_VALUE)
        goto L1;                        // failure
    debug(printf) printf(" file created\n");

    // Windows 95 does not implement PAGE_WRITECOPY (unfortunately treating
    // it just like PAGE_READWRITE).
    if (flag == 1 && OsVerInfo.dwPlatformId == 1)       // Windows 95, 98, ME
        hFileMap = null;
    else
        hFileMap = CreateFileMappingA(hFile,null,
                (flag == 1) ? PAGE_WRITECOPY : PAGE_READWRITE,0,size,null);

    if (hFileMap == null)               // mapping failed
    {
version(all)
{
        // Win32s seems to always fail here.
        DWORD nbytes;

        debug(printf) printf(" mapping failed\n");
        // If it was NT failing, assert.
        assert(OsVerInfo.dwPlatformId != VER_PLATFORM_WIN32_NT);

        // To work around, just read the file into memory.
        assert(flag == 1);
        preserve = vmem_reserve(ptr,size);
        if (!preserve)
            goto L2;
        if (!vmem_commit(preserve,size))
        {
            vmem_release(preserve,size);
            preserve = null;
            goto L2;
        }
        preserve_size = size;
        if (!ReadFile(hFile,preserve,size,&nbytes,null))
            os_error();
        assert(nbytes == size);
        if (CloseHandle(hFile) != true)
            os_error();
        hFile = INVALID_HANDLE_VALUE;
        return preserve;
}
else
{
        // Instead of working around, we should find out why it failed.
        os_error();
}

    }
    else
    {
        debug(printf) printf(" mapping created\n");
        pview = MapViewOfFileEx(hFileMap,flag ? FILE_MAP_COPY : FILE_MAP_WRITE,
                0,0,size,ptr);
        if (pview == null)                      // mapping view failed
        {   //os_error();
            goto L3;
        }
    }
    debug(printf) printf(" pview = %p\n",pview);

    return pview;

L3:
    if (CloseHandle(hFileMap) != true)
        os_error();
    hFileMap = null;
L2:
    if (CloseHandle(hFile) != true)
        os_error();
    hFile = INVALID_HANDLE_VALUE;
L1:
    return null;                        // failure
}

/*****************************
 * Set size of mapped file.
 */

@trusted
void vmem_setfilesize(uint size)
{
    if (hFile != INVALID_HANDLE_VALUE)
    {   if (SetFilePointer(hFile,size,null,FILE_BEGIN) == 0xFFFFFFFF)
            os_error();
        if (SetEndOfFile(hFile) == false)
            os_error();
    }
}

/*****************************
 * Unmap previous file mapping.
 */

@trusted
void vmem_unmapfile()
{
    debug(printf) printf("vmem_unmapfile()\n");

    vmem_decommit(preserve,preserve_size);
    vmem_release(preserve,preserve_size);
    preserve = null;
    preserve_size = 0;

version(none)
{
    if (pview)
    {   int i;

        i = UnmapViewOfFile(pview);
        debug(printf) printf("i = x%x\n",i);
        if (i == false)
            os_error();
    }
}
else
{
    // Note that under Windows 95, UnmapViewOfFile() seems to return random
    // values, not TRUE or FALSE.
    if (pview && UnmapViewOfFile(pview) == false)
        os_error();
}
    pview = null;

    if (hFileMap != null && CloseHandle(hFileMap) != true)
        os_error();
    hFileMap = null;

    if (hFile != INVALID_HANDLE_VALUE && CloseHandle(hFile) != true)
        os_error();
    hFile = INVALID_HANDLE_VALUE;
}

/****************************************
 * Determine a base address that we can use for mapping files to.
 */

@trusted
void *vmem_baseaddr()
{
    OSVERSIONINFO OsVerInfo;
    void *p;

    OsVerInfo.dwOSVersionInfoSize = OsVerInfo.sizeof;
    GetVersionEx(&OsVerInfo);

    // These values for the address were determined by trial and error.
    switch (OsVerInfo.dwPlatformId)
    {
        case VER_PLATFORM_WIN32s:               // Win32s
            // The fact that this is a different address than other
            // WIN32 implementations causes us a lot of grief.
            p = cast(void *) 0xC0000000;
            break;

        case 1: //VER_PLATFORM_WIN32_WINDOWS:   // Windows 95
            // I've found 0x90000000..0xB work. All others fail.
        default:                                // unknown
            p = cast(void *) 0x90000000;
            break;

        case VER_PLATFORM_WIN32_NT:             // Windows NT
            // Pick a value that is not coincident with the base address
            // of any commonly used system DLLs.
            p = cast(void *) 0x38000000;
            break;
    }

    return p;
}

/********************************************
 * Calculate the amount of memory to reserve, adjusting
 * *psize downwards.
 */

@trusted
void vmem_reservesize(uint *psize)
{
    MEMORYSTATUS ms;
    OSVERSIONINFO OsVerInfo;

    uint size;

    ms.dwLength = ms.sizeof;
    GlobalMemoryStatus(&ms);
    debug(printf) printf("dwMemoryLoad    x%lx\n",ms.dwMemoryLoad);
    debug(printf) printf("dwTotalPhys     x%lx\n",ms.dwTotalPhys);
    debug(printf) printf("dwAvailPhys     x%lx\n",ms.dwAvailPhys);
    debug(printf) printf("dwTotalPageFile x%lx\n",ms.dwTotalPageFile);
    debug(printf) printf("dwAvailPageFile x%lx\n",ms.dwAvailPageFile);
    debug(printf) printf("dwTotalVirtual  x%lx\n",ms.dwTotalVirtual);
    debug(printf) printf("dwAvailVirtual  x%lx\n",ms.dwAvailVirtual);


    OsVerInfo.dwOSVersionInfoSize = OsVerInfo.sizeof;
    GetVersionEx(&OsVerInfo);

    switch (OsVerInfo.dwPlatformId)
    {
        case VER_PLATFORM_WIN32s:               // Win32s
        case 1: //VER_PLATFORM_WIN32_WINDOWS:   // Windows 95
        default:                                // unknown
            size = (ms.dwAvailPageFile < ms.dwAvailVirtual)
                ? ms.dwAvailPageFile
                : ms.dwAvailVirtual;
            size = cast(ulong)size * 8 / 10;
            size &= ~0xFFFF;
            if (size < *psize)
                *psize = size;
            break;

        case VER_PLATFORM_WIN32_NT:             // Windows NT
            // NT can expand the paging file
            break;
    }

}

/********************************************
 * Return amount of physical memory.
 */

@trusted
uint vmem_physmem()
{
    MEMORYSTATUS ms;

    ms.dwLength = ms.sizeof;
    GlobalMemoryStatus(&ms);
    return ms.dwTotalPhys;
}

//////////////////////////////////////////////////////////////

/***************************************************
 * Load library.
 */

private __gshared HINSTANCE hdll;

@trusted
void os_loadlibrary(const char *dllname)
{
    hdll = LoadLibrary(cast(LPCTSTR) dllname);
    if (!hdll)
        os_error();
}

/*************************************************
 */

@trusted
void os_freelibrary()
{
    if (hdll)
    {
        if (FreeLibrary(hdll) != true)
            os_error();
        hdll = null;
    }
}

/*************************************************
 */

@trusted
void *os_getprocaddress(const char *funcname)
{   void *fp;

    //printf("getprocaddress('%s')\n",funcname);
    assert(hdll);
    fp = cast(void *)GetProcAddress(hdll,cast(LPCSTR)funcname);
    if (!fp)
        os_error();
    return fp;
}

//////////////////////////////////////////////////////////////


/*********************************
 */

@trusted
void os_term()
{
    if (hHeap)
    {   if (HeapDestroy(hHeap) == false)
        {   hHeap = null;
            os_error();
        }
        hHeap = null;
    }
    os_freelibrary();
}

/***************************************************
 * Do our own storage allocator (being suspicious of the library one).
 */

version(all)
{
void os_heapinit() { }
void os_heapterm() { }

}
else
{
static HANDLE hHeap;

void os_heapinit()
{
    hHeap = HeapCreate(0,0x10000,0);
    if (!hHeap)
        os_error();
}

void os_heapterm()
{
    if (hHeap)
    {   if (HeapDestroy(hHeap) == false)
            os_error();
    }
}

extern(Windows) void * calloc(size_t x,size_t y)
{   size_t size;

    size = x * y;
    return size ? HeapAlloc(hHeap,HEAP_ZERO_MEMORY,size) : null;
}

extern(Windows) void free(void *p)
{
    if (p && HeapFree(hHeap,0,p) == false)
        os_error();
}

extern(Windows) void * malloc(size_t size)
{
    return size ? HeapAlloc(hHeap,0,size) : null;
}

extern(Windows) void * realloc(void *p,size_t newsize)
{
    if (newsize == 0)
        free(p);
    else if (!p)
        p = malloc(newsize);
    else
        p = HeapReAlloc(hHeap,0,p,newsize);
    return p;
}

}

//////////////////////////////////////////
// Return a value that will hopefully be unique every time
// we call it.

@trusted
uint os_unique()
{
    ulong x;

    QueryPerformanceCounter(cast(LARGE_INTEGER *)&x);
    return cast(uint)x;
}

} // Win32

/*******************************************
 * Return !=0 if file exists.
 *      0:      file doesn't exist
 *      1:      normal file
 *      2:      directory
 */

@trusted
int os_file_exists(const char *name)
{
version(Windows)
{
    DWORD dw;
    int result;

    dw = GetFileAttributesA(name);
    if (dw == -1L)
        result = 0;
    else if (dw & FILE_ATTRIBUTE_DIRECTORY)
        result = 2;
    else
        result = 1;
    return result;
}
else version(Posix)
{
    stat_t buf;

    return stat(name,&buf) == 0;        /* file exists if stat succeeded */

}
else
{
    return filesize(name) != -1L;
}
}

/**************************************
 * Get file size of open file. Return -1L on error.
 */

static if(NEEDS_WIN32_NON_MS)
{
    extern extern (C) void*[] _osfhnd;
}

@trusted
long os_file_size(int fd)
{
    static if (NEEDS_WIN32_NON_MS)
    {
        return GetFileSize(_osfhnd[fd],null);
    }
    else
    {
        version(Windows)
        {
            return GetFileSize(cast(void*)_get_osfhandle(fd),null);
        }
        else
        {
            stat_t buf;
            return (fstat(fd,&buf)) ? -1L : buf.st_size;
        }
    }
}

/**************************************************
 * For 16 bit programs, we need the 16 bit filename.
 * Returns:
 *      malloc'd string, NULL if none
 */

version(Windows)
{
@trusted
char *file_8dot3name(const char *filename)
{
    HANDLE h;
    WIN32_FIND_DATAA fileinfo;
    char *buf;
    size_t i;

    h = FindFirstFileA(filename,&fileinfo);
    if (h == INVALID_HANDLE_VALUE)
        return null;
    if (fileinfo.cAlternateFileName[0])
    {
        for (i = strlen(filename); i > 0; i--)
            if (filename[i] == '\\' || filename[i] == ':')
            {   i++;
                break;
            }
        buf = cast(char *) malloc(i + 14);
        if (buf)
        {
            memcpy(buf,filename,i);
            strcpy(buf + i,fileinfo.cAlternateFileName.ptr);
        }
    }
    else
        buf = strdup(filename);
    FindClose(h);
    return buf;
}
}

/**********************************************
 * Write a file.
 * Returns:
 *      0       success
 */

@trusted
int file_write(char *name, void *buffer, uint len)
{
version(Posix)
{
    int fd;
    ssize_t numwritten;

    fd = open(name, O_CREAT | O_WRONLY | O_TRUNC,
            S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP);
    if (fd == -1)
        goto err;

    numwritten = .write(fd, buffer, len);
    if (len != numwritten)
        goto err2;

    if (close(fd) == -1)
        goto err;

    return 0;

err2:
    close(fd);
err:
    return 1;
}
else version(Windows)
{
    HANDLE h;
    DWORD numwritten;

    h = CreateFileA(cast(LPCSTR)name,GENERIC_WRITE,0,null,CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,null);
    if (h == INVALID_HANDLE_VALUE)
    {
        if (GetLastError() == ERROR_PATH_NOT_FOUND)
        {
            if (!file_createdirs(name))
            {
                h = CreateFileA(cast(LPCSTR)name, GENERIC_WRITE, 0, null, CREATE_ALWAYS,
                    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,null);
                if (h != INVALID_HANDLE_VALUE)
                    goto Lok;
            }
        }
        goto err;
    }

Lok:
    if (WriteFile(h,buffer,len,&numwritten,null) != true)
        goto err2;

    if (len != numwritten)
        goto err2;

    if (!CloseHandle(h))
        goto err;
    return 0;

err2:
    CloseHandle(h);
err:
    return 1;
}
}

/********************************
 * Create directories up to filename.
 * Input:
 *      name    path/filename
 * Returns:
 *      0       success
 *      !=0     failure
 */

@trusted
int file_createdirs(char *name)
{
version(Posix)
{
    return 1;
}
else version(Windows)
{
    auto len = strlen(name);
    char *path = cast(char *)alloca(len + 1);
    char *p;

    memcpy(path, name, len + 1);

    for (p = path + len; ; p--)
    {
        if (p == path)
            goto Lfail;
        switch (*p)
        {
            case ':':
            case '/':
            case '\\':
                *p = 0;
                if (!CreateDirectory(cast(LPTSTR)path, null))
                {   // Failed
                    if (file_createdirs(path))
                        goto Lfail;
                    if (!CreateDirectory(cast(LPTSTR)path, null))
                        goto Lfail;
                }
                return 0;
            default:
                continue;
        }
    }

Lfail:
    return 1;
}
}

/***********************************
 * Returns:
 *   result of C library clock()
 */

int os_clock()
{
    return cast(int) clock();
}

/***********************************
 * Return size of OS critical section.
 * NOTE: can't use the sizeof() calls directly since cross compiling is
 * supported and would end up using the host sizes rather than the target
 * sizes.
 */



version(Windows)
{
int os_critsecsize32()
{
    return 24;  // sizeof(CRITICAL_SECTION) for 32 bit Windows
}

int os_critsecsize64()
{
    return 40;  // sizeof(CRITICAL_SECTION) for 64 bit Windows
}
}
else version(linux)
{
int os_critsecsize32()
{
    return 24; // sizeof(pthread_mutex_t) on 32 bit
}

int os_critsecsize64()
{
    return 40; // sizeof(pthread_mutex_t) on 64 bit
}
}

else version(FreeBSD)
{
int os_critsecsize32()
{
    return 4; // sizeof(pthread_mutex_t) on 32 bit
}

int os_critsecsize64()
{
    return 8; // sizeof(pthread_mutex_t) on 64 bit
}
}

else version(OpenBSD)
{
int os_critsecsize32()
{
    return 4; // sizeof(pthread_mutex_t) on 32 bit
}

int os_critsecsize64()
{
    return 8; // sizeof(pthread_mutex_t) on 64 bit
}
}
else version(DragonFlyBSD)
{
int os_critsecsize32()
{
    return 4; // sizeof(pthread_mutex_t) on 32 bit
}

int os_critsecsize64()
{
    return 8; // sizeof(pthread_mutex_t) on 64 bit
}
}

else version (OSX)
{
int os_critsecsize32()
{
    version(X86_64)
    {
        assert(pthread_mutex_t.sizeof == 64);
    }
    else
    {
        assert(pthread_mutex_t.sizeof == 44);
    }
    return 44;
}

int os_critsecsize64()
{
    return 64;
}
}

else version(Solaris)
{
int os_critsecsize32()
{
    return sizeof(pthread_mutex_t);
}

int os_critsecsize64()
{
    assert(0);
    return 0;
}
}

/* This is the magic program to get the size on Posix systems:

#if 0
#include <stdio.h>
#include <pthread.h>

int main()
{
    printf("%d\n", (int)sizeof(pthread_mutex_t));
    return 0;
}
#endif

#endif
*/
