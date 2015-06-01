// Copyright (C) 1994-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/*
 * Operating system specific routines.
 * Placed here to avoid cluttering
 * up code with OS .h files.
 */

#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>

#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <pthread.h>
#define GetLastError() errno
#elif _WIN32
#include <dos.h>
#include <sys\stat.h>
#include        <windows.h>
#endif

#if __DMC__ || __GNUC__ || _MSC_VER
static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"
#else
#include        <assert.h>
#endif

#if _MSC_VER
#include <alloca.h>
#endif

#if _WINDLL
extern void dll_printf(const char *format,...);
#define dbg_printf dll_printf
#else
#define dbg_printf printf
#endif

int file_createdirs(char *name);

/***********************************
 * Called when there is an error returned by the operating system.
 * This function does not return.
 */

#if _MSC_VER
__declspec(noreturn)
#endif
void os_error(int line)
{
#if _WIN32
    dbg_printf("System error: %ldL\n",GetLastError());
#endif
    local_assert(line);
}

#if 1
#undef dbg_printf
#define dbg_printf      (void)
#endif

#define os_error() os_error(__LINE__)
#if __DMC__
#pragma noreturn(os_error)
#endif

#if _WIN32
/*********************************
 * Allocate a chunk of memory from the operating system.
 * Bypass malloc and friends.
 */

static HANDLE hHeap;

void *globalrealloc(void *oldp,size_t newsize)
{
#if 0
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
        if (oldp && HeapFree(hHeap,0,oldp) == FALSE)
            os_error();
        p = NULL;
    }
    else if (!oldp)
    {
        p = newsize ? HeapAlloc(hHeap,0,newsize) : NULL;
    }
    else
        p = HeapReAlloc(hHeap,0,oldp,newsize);
#elif 1
    MEMORY_BASIC_INFORMATION query;
    void *p;
    BOOL bSuccess;

    if (!oldp)
        p = VirtualAlloc (NULL, newsize, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    else
    {
        VirtualQuery (oldp, &query, sizeof(query));
        if (!newsize)
        {
            p = NULL;
            goto L1;
        }
        else
        {   newsize = (newsize + 0xFFFF) & ~0xFFFFL;

            if (query.RegionSize >= newsize)
                p = oldp;
            else
            {   p = VirtualAlloc(NULL,newsize,MEM_COMMIT | MEM_RESERVE,PAGE_READWRITE);
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
#else
    void *p;

    if (!oldp)
        p = (void *)GlobalAlloc (0, newsize);
    else if (!newsize)
    {   GlobalFree(oldp);
        p = NULL;
    }
    else
        p = (void *)GlobalReAlloc(oldp,newsize,0);
#endif
    dbg_printf("globalrealloc(oldp = %p, size = x%x) = %p\n",oldp,newsize,p);
    return p;
}

/*****************************************
 * Functions to manage allocating a single virtual address space.
 */

void *vmem_reserve(void *ptr,unsigned long size)
{   void *p;

#if 1
    p = VirtualAlloc(ptr,size,MEM_RESERVE,PAGE_READWRITE);
    dbg_printf("vmem_reserve(ptr = %p, size = x%lx) = %p\n",ptr,size,p);
#else
    dbg_printf("vmem_reserve(ptr = %p, size = x%lx) = %p\n",ptr,size,p);
    p = VirtualAlloc(ptr,size,MEM_RESERVE,PAGE_READWRITE);
    if (!p)
        os_error();
#endif
    return p;
}

/*****************************************
 * Commit memory.
 * Returns:
 *      0       failure
 *      !=0     success
 */

int vmem_commit(void *ptr, unsigned long size)
{   int i;

    dbg_printf("vmem_commit(ptr = %p,size = x%lx)\n",ptr,size);
    i = (int) VirtualAlloc(ptr,size,MEM_COMMIT,PAGE_READWRITE);
    if (i == 0)
        dbg_printf("failed to commit\n");
    return i;
}

void vmem_decommit(void *ptr,unsigned long size)
{
    dbg_printf("vmem_decommit(ptr = %p, size = x%lx)\n",ptr,size);
    if (ptr)
    {   if (!VirtualFree(ptr, size, MEM_DECOMMIT))
            os_error();
    }
}

void vmem_release(void *ptr,unsigned long size)
{
    dbg_printf("vmem_release(ptr = %p, size = x%lx)\n",ptr,size);
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

static HANDLE hFile = INVALID_HANDLE_VALUE;
static HANDLE hFileMap = NULL;
static void *pview;
static void *preserve;
static size_t preserve_size;

void *vmem_mapfile(const char *filename,void *ptr,unsigned long size,int flag)
{
    OSVERSIONINFO OsVerInfo;

    OsVerInfo.dwOSVersionInfoSize = sizeof(OsVerInfo);
    GetVersionEx(&OsVerInfo);

    dbg_printf("vmem_mapfile(filename = '%s', ptr = %p, size = x%lx, flag = %d)\n",filename,ptr,size,flag);

    hFile = CreateFileA(filename, GENERIC_READ | GENERIC_WRITE,
                        FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE)
        goto L1;                        // failure
    dbg_printf(" file created\n");

    // Windows 95 does not implement PAGE_WRITECOPY (unfortunately treating
    // it just like PAGE_READWRITE).
    if (flag == 1 && OsVerInfo.dwPlatformId == 1)       // Windows 95, 98, ME
        hFileMap = NULL;
    else
        hFileMap = CreateFileMappingA(hFile,NULL,
                (flag == 1) ? PAGE_WRITECOPY : PAGE_READWRITE,0,size,NULL);

    if (hFileMap == NULL)               // mapping failed
    {
#if 1
        // Win32s seems to always fail here.
        DWORD nbytes;

        dbg_printf(" mapping failed\n");
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
            preserve = NULL;
            goto L2;
        }
        preserve_size = size;
        if (!ReadFile(hFile,preserve,size,&nbytes,NULL))
            os_error();
        assert(nbytes == size);
        if (CloseHandle(hFile) != TRUE)
            os_error();
        hFile = INVALID_HANDLE_VALUE;
        return preserve;
#else
        // Instead of working around, we should find out why it failed.
        os_error();
#endif
    }
    else
    {
        dbg_printf(" mapping created\n");
        pview = MapViewOfFileEx(hFileMap,flag ? FILE_MAP_COPY : FILE_MAP_WRITE,
                0,0,size,ptr);
        if (pview == NULL)                      // mapping view failed
        {   //os_error();
            goto L3;
        }
    }
    dbg_printf(" pview = %p\n",pview);

    return pview;

Terminate:
    if (UnmapViewOfFile(pview) == FALSE)
        os_error();
    pview = NULL;
L3:
    if (CloseHandle(hFileMap) != TRUE)
        os_error();
    hFileMap = NULL;
L2:
    if (CloseHandle(hFile) != TRUE)
        os_error();
    hFile = INVALID_HANDLE_VALUE;
L1:
    return NULL;                        // failure
}

/*****************************
 * Set size of mapped file.
 */

void vmem_setfilesize(unsigned long size)
{
    if (hFile != INVALID_HANDLE_VALUE)
    {   if (SetFilePointer(hFile,size,NULL,FILE_BEGIN) == 0xFFFFFFFF)
            os_error();
        if (SetEndOfFile(hFile) == FALSE)
            os_error();
    }
}

/*****************************
 * Unmap previous file mapping.
 */

void vmem_unmapfile()
{
    dbg_printf("vmem_unmapfile()\n");

    vmem_decommit(preserve,preserve_size);
    vmem_release(preserve,preserve_size);
    preserve = NULL;
    preserve_size = 0;

#if 0
    if (pview)
    {   int i;

        i = UnmapViewOfFile(pview);
        dbg_printf("i = x%x\n",i);
        if (i == FALSE)
            os_error();
    }
#else
    // Note that under Windows 95, UnmapViewOfFile() seems to return random
    // values, not TRUE or FALSE.
    if (pview && UnmapViewOfFile(pview) == FALSE)
        os_error();
#endif
    pview = NULL;

    if (hFileMap != NULL && CloseHandle(hFileMap) != TRUE)
        os_error();
    hFileMap = NULL;

    if (hFile != INVALID_HANDLE_VALUE && CloseHandle(hFile) != TRUE)
        os_error();
    hFile = INVALID_HANDLE_VALUE;
}

/****************************************
 * Determine a base address that we can use for mapping files to.
 */

void *vmem_baseaddr()
{
    OSVERSIONINFO OsVerInfo;
    void *p;

    OsVerInfo.dwOSVersionInfoSize = sizeof(OsVerInfo);
    GetVersionEx(&OsVerInfo);

    // These values for the address were determined by trial and error.
    switch (OsVerInfo.dwPlatformId)
    {
        case VER_PLATFORM_WIN32s:               // Win32s
            // The fact that this is a different address than other
            // WIN32 implementations causes us a lot of grief.
            p = (void *) 0xC0000000;
            break;

        case 1: //VER_PLATFORM_WIN32_WINDOWS:   // Windows 95
            // I've found 0x90000000..0xB work. All others fail.
        default:                                // unknown
            p = (void *) 0x90000000;
            break;

        case VER_PLATFORM_WIN32_NT:             // Windows NT
            // Pick a value that is not coincident with the base address
            // of any commonly used system DLLs.
            p = (void *) 0x38000000;
            break;
    }

    return p;
}

/********************************************
 * Calculate the amount of memory to reserve, adjusting
 * *psize downwards.
 */

void vmem_reservesize(unsigned long *psize)
{
    MEMORYSTATUS ms;
    OSVERSIONINFO OsVerInfo;

    unsigned long size;

    ms.dwLength = sizeof(ms);
    GlobalMemoryStatus(&ms);
    dbg_printf("dwMemoryLoad    x%lx\n",ms.dwMemoryLoad);
    dbg_printf("dwTotalPhys     x%lx\n",ms.dwTotalPhys);
    dbg_printf("dwAvailPhys     x%lx\n",ms.dwAvailPhys);
    dbg_printf("dwTotalPageFile x%lx\n",ms.dwTotalPageFile);
    dbg_printf("dwAvailPageFile x%lx\n",ms.dwAvailPageFile);
    dbg_printf("dwTotalVirtual  x%lx\n",ms.dwTotalVirtual);
    dbg_printf("dwAvailVirtual  x%lx\n",ms.dwAvailVirtual);


    OsVerInfo.dwOSVersionInfoSize = sizeof(OsVerInfo);
    GetVersionEx(&OsVerInfo);

    switch (OsVerInfo.dwPlatformId)
    {
        case VER_PLATFORM_WIN32s:               // Win32s
        case 1: //VER_PLATFORM_WIN32_WINDOWS:   // Windows 95
        default:                                // unknown
            size = (ms.dwAvailPageFile < ms.dwAvailVirtual)
                ? ms.dwAvailPageFile
                : ms.dwAvailVirtual;
            size = (unsigned long long)size * 8 / 10;
            size &= ~0xFFFFL;
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

unsigned long vmem_physmem()
{
    MEMORYSTATUS ms;

    ms.dwLength = sizeof(ms);
    GlobalMemoryStatus(&ms);
    return ms.dwTotalPhys;
}

//////////////////////////////////////////////////////////////

/***************************************************
 * Load library.
 */

static HINSTANCE hdll;

void os_loadlibrary(const char *dllname)
{
    hdll = LoadLibrary((LPCTSTR) dllname);
    if (!hdll)
        os_error();
}

/*************************************************
 */

void os_freelibrary()
{
    if (hdll)
    {
        if (FreeLibrary(hdll) != TRUE)
            os_error();
        hdll = NULL;
    }
}

/*************************************************
 */

void *os_getprocaddress(const char *funcname)
{   void *fp;

    //printf("getprocaddress('%s')\n",funcname);
    assert(hdll);
    fp = (void *)GetProcAddress(hdll,(LPCSTR)funcname);
    if (!fp)
        os_error();
    return fp;
}

//////////////////////////////////////////////////////////////


/*********************************
 */

void os_term()
{
    if (hHeap)
    {   if (HeapDestroy(hHeap) == FALSE)
        {   hHeap = NULL;
            os_error();
        }
        hHeap = NULL;
    }
    os_freelibrary();
}

/***************************************************
 * Do our own storage allocator (being suspicious of the library one).
 */

#if 1

void os_heapinit() { }
void os_heapterm() { }

#else

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
    {   if (HeapDestroy(hHeap) == FALSE)
            os_error();
    }
}

void *  __cdecl calloc(size_t x,size_t y)
{   size_t size;

    size = x * y;
    return size ? HeapAlloc(hHeap,HEAP_ZERO_MEMORY,size) : NULL;
}

void    __cdecl free(void *p)
{
    if (p && HeapFree(hHeap,0,p) == FALSE)
        os_error();
}

void *  __cdecl malloc(size_t size)
{
    return size ? HeapAlloc(hHeap,0,size) : NULL;
}

void *  __cdecl realloc(void *p,size_t newsize)
{
    if (newsize == 0)
        free(p);
    else if (!p)
        p = malloc(newsize);
    else
        p = HeapReAlloc(hHeap,0,p,newsize);
    return p;
}

#endif

//////////////////////////////////////////
// Return a value that will hopefully be unique every time
// we call it.

unsigned long os_unique()
{
    unsigned long long x;

    QueryPerformanceCounter((LARGE_INTEGER *)&x);
    return x;
}

#endif

/*******************************************
 * Return !=0 if file exists.
 *      0:      file doesn't exist
 *      1:      normal file
 *      2:      directory
 */

int os_file_exists(const char *name)
{
#if _WIN32
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
#elif __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    struct stat buf;

    return stat(name,&buf) == 0;        /* file exists if stat succeeded */

#else
    return filesize(name) != -1L;
#endif
}

/**************************************
 * Get file size of open file. Return -1L on error.
 */

#if _WIN32 && !_MSC_VER
extern "C" void * __cdecl _osfhnd[];
#endif

long os_file_size(int fd)
{
#if _WIN32 && !_MSC_VER
    return GetFileSize(_osfhnd[fd],NULL);
#else
    struct stat buf;

    return (fstat(fd,&buf)) ? -1L : buf.st_size;
#endif
}

/**************************************************
 * For 16 bit programs, we need the 16 bit filename.
 * Returns:
 *      malloc'd string, NULL if none
 */

#if _WIN32

char *file_8dot3name(const char *filename)
{
    HANDLE h;
    WIN32_FIND_DATAA fileinfo;
    char *buf;
    int i;

    h = FindFirstFileA(filename,&fileinfo);
    if (h == INVALID_HANDLE_VALUE)
        return NULL;
    if (fileinfo.cAlternateFileName[0])
    {
        for (i = strlen(filename); i > 0; i--)
            if (filename[i] == '\\' || filename[i] == ':')
            {   i++;
                break;
            }
        buf = (char *) malloc(i + 14);
        if (buf)
        {
            memcpy(buf,filename,i);
            strcpy(buf + i,fileinfo.cAlternateFileName);
        }
    }
    else
        buf = strdup(filename);
    FindClose(h);
    return buf;
}

#endif

/**********************************************
 * Write a file.
 * Returns:
 *      0       success
 */

int file_write(char *name, void *buffer, unsigned len)
{
#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    int fd;
    ssize_t numwritten;

    fd = open(name, O_CREAT | O_WRONLY | O_TRUNC,
            S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP);
    if (fd == -1)
        goto err;

    numwritten = ::write(fd, buffer, len);
    if (len != numwritten)
        goto err2;

    if (close(fd) == -1)
        goto err;

    return 0;

err2:
    close(fd);
err:
    return 1;
#endif
#if _WIN32
    HANDLE h;
    DWORD numwritten;

    h = CreateFileA((LPCSTR)name,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,NULL);
    if (h == INVALID_HANDLE_VALUE)
    {
        if (GetLastError() == ERROR_PATH_NOT_FOUND)
        {
            if (!file_createdirs(name))
            {
                h = CreateFileA((LPCSTR)name, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,NULL);
                if (h != INVALID_HANDLE_VALUE)
                    goto Lok;
            }
        }
        goto err;
    }

Lok:
    if (WriteFile(h,buffer,len,&numwritten,NULL) != TRUE)
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
#endif
}

/********************************
 * Create directories up to filename.
 * Input:
 *      name    path/filename
 * Returns:
 *      0       success
 *      !=0     failure
 */

int file_createdirs(char *name)
{
#if __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun
    return 1;
#endif
#if _WIN32
    int len = strlen(name);
    char *path = (char *)alloca(len + 1);
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
                if (!CreateDirectory((LPTSTR)path, NULL))
                {   // Failed
                    if (file_createdirs(path))
                        goto Lfail;
                    if (!CreateDirectory((LPTSTR)path, NULL))
                        goto Lfail;
                }
                return 0;
        }
    }

Lfail:
    return 1;
#endif
}

/***********************************
 * Return size of OS critical section.
 * NOTE: can't use the sizeof() calls directly since cross compiling is
 * supported and would end up using the host sizes rather than the target
 * sizes.
 */

#if DMDV1

#if _WIN32
int os_critsecsize32()
{
    return 24;  // sizeof(CRITICAL_SECTION) for 32 bit Windows
}

int os_critsecsize64()
{
    return 40;  // sizeof(CRITICAL_SECTION) for 64 bit Windows
}
#endif

#if __linux__
int os_critsecsize32()
{
    return 24; // sizeof(pthread_mutex_t) on 32 bit
}

int os_critsecsize64()
{
    return 40; // sizeof(pthread_mutex_t) on 64 bit
}
#endif

#if __FreeBSD__
int os_critsecsize32()
{
    return 4; // sizeof(pthread_mutex_t) on 32 bit
}

int os_critsecsize64()
{
    return 8; // sizeof(pthread_mutex_t) on 64 bit
}
#endif

#if __OpenBSD__
int os_critsecsize32()
{
    return 4; // sizeof(pthread_mutex_t) on 32 bit
}

int os_critsecsize64()
{
    assert(0);
    return 8; // sizeof(pthread_mutex_t) on 64 bit
}
#endif

#if __APPLE__
int os_critsecsize32()
{
#if __LP64__    // check for bit rot
    assert(sizeof(pthread_mutex_t) == 64);
#else
    assert(sizeof(pthread_mutex_t) == 44);
#endif
    return 44;
}

int os_critsecsize64()
{
    return 64;
}
#endif


#if __sun
int os_critsecsize32()
{
    return sizeof(pthread_mutex_t);
}

int os_critsecsize64()
{
    assert(0);
    return 0;
}
#endif

/* This is the magic program to get the size on Posix systems: */

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
