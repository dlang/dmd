
/* Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved, written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * (See accompanying file LICENSE or copy at http://www.boost.org/LICENSE_1_0.txt)
 * https://github.com/D-Programming-Language/dmd/blob/master/src/root/file.c
 */

#include "file.h"

#if defined (__sun)
#include <alloca.h>
#endif

#if _MSC_VER ||__MINGW32__
#include <malloc.h>
#include <string>
#endif

#if _WIN32
#include <windows.h>
#include <direct.h>
#include <errno.h>
#endif

#if POSIX
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <utime.h>
#endif

#include "filename.h"
#include "array.h"
#include "port.h"
#include "rmem.h"

/****************************** File ********************************/

File::File(const FileName *n)
{
    ref = 0;
    buffer = NULL;
    len = 0;
    touchtime = NULL;
    name = (FileName *)n;
}

File *File::create(const char *n)
{
    return new File(n);
}

File::File(const char *n)
{
    ref = 0;
    buffer = NULL;
    len = 0;
    touchtime = NULL;
    name = new FileName(n);
}

File::~File()
{
    if (buffer)
    {
        if (ref == 0)
            mem.free(buffer);
#if _WIN32
        if (ref == 2)
            UnmapViewOfFile(buffer);
#endif
    }
    if (touchtime)
        mem.free(touchtime);
}

/*************************************
 */

int File::read()
{
    if (len)
        return 0;               // already read the file
#if POSIX
    size_t size;
    ssize_t numread;
    int fd;
    struct stat buf;
    int result = 0;
    char *name;

    name = this->name->toChars();
    //printf("File::read('%s')\n",name);
    fd = open(name, O_RDONLY);
    if (fd == -1)
    {
        //printf("\topen error, errno = %d\n",errno);
        goto err1;
    }

    if (!ref)
        ::free(buffer);
    ref = 0;       // we own the buffer now

    //printf("\tfile opened\n");
    if (fstat(fd, &buf))
    {
        printf("\tfstat error, errno = %d\n",errno);
        goto err2;
    }
    size = (size_t)buf.st_size;
    buffer = (unsigned char *) ::malloc(size + 2);
    if (!buffer)
    {
        printf("\tmalloc error, errno = %d\n",errno);
        goto err2;
    }

    numread = ::read(fd, buffer, size);
    if (numread != size)
    {
        printf("\tread error, errno = %d\n",errno);
        goto err2;
    }

    if (touchtime)
        memcpy(touchtime, &buf, sizeof(buf));

    if (close(fd) == -1)
    {
        printf("\tclose error, errno = %d\n",errno);
        goto err;
    }

    len = size;

    // Always store a wchar ^Z past end of buffer so scanner has a sentinel
    buffer[size] = 0;           // ^Z is obsolete, use 0
    buffer[size + 1] = 0;
    return 0;

err2:
    close(fd);
err:
    ::free(buffer);
    buffer = NULL;
    len = 0;

err1:
    result = 1;
    return result;
#elif _WIN32
    DWORD size;
    DWORD numread;
    HANDLE h;
    int result = 0;
    char *name;

    name = this->name->toChars();
    h = CreateFileA(name,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,NULL);
    if (h == INVALID_HANDLE_VALUE)
        goto err1;

    if (!ref)
        ::free(buffer);
    ref = 0;

    size = GetFileSize(h,NULL);
    buffer = (unsigned char *) ::malloc(size + 2);
    if (!buffer)
        goto err2;

    if (ReadFile(h,buffer,size,&numread,NULL) != TRUE)
        goto err2;

    if (numread != size)
        goto err2;

    if (touchtime)
    {
        if (!GetFileTime(h, NULL, NULL, &((WIN32_FIND_DATAA *)touchtime)->ftLastWriteTime))
            goto err2;
    }

    if (!CloseHandle(h))
        goto err;

    len = size;

    // Always store a wchar ^Z past end of buffer so scanner has a sentinel
    buffer[size] = 0;           // ^Z is obsolete, use 0
    buffer[size + 1] = 0;
    return 0;

err2:
    CloseHandle(h);
err:
    ::free(buffer);
    buffer = NULL;
    len = 0;

err1:
    result = 1;
    return result;
#else
    assert(0);
#endif
}

/*****************************
 * Read a file with memory mapped file I/O.
 */

int File::mmread()
{
#if POSIX
    return read();
#elif _WIN32
    HANDLE hFile;
    HANDLE hFileMap;
    DWORD size;
    char *name;

    name = this->name->toChars();
    hFile = CreateFileA(name, GENERIC_READ,
                        FILE_SHARE_READ, NULL,
                        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE)
        goto Lerr;
    size = GetFileSize(hFile, NULL);
    //printf(" file created, size %d\n", size);

    hFileMap = CreateFileMappingA(hFile,NULL,PAGE_READONLY,0,size,NULL);
    if (CloseHandle(hFile) != TRUE)
        goto Lerr;

    if (hFileMap == NULL)
        goto Lerr;

    //printf(" mapping created\n");

    if (!ref)
        mem.free(buffer);
    ref = 2;
    buffer = (unsigned char *)MapViewOfFileEx(hFileMap, FILE_MAP_READ,0,0,size,NULL);
    if (CloseHandle(hFileMap) != TRUE)
        goto Lerr;
    if (buffer == NULL)                 // mapping view failed
        goto Lerr;

    len = size;
    //printf(" buffer = %p\n", buffer);

    return 0;

Lerr:
    return GetLastError();                      // failure
#else
    assert(0);
#endif
}

/*********************************************
 * Write a file.
 * Returns:
 *      0       success
 */

int File::write()
{
#if POSIX
    int fd;
    ssize_t numwritten;
    char *name;

    name = this->name->toChars();
    fd = open(name, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd == -1)
        goto err;

    numwritten = ::write(fd, buffer, len);
    if (len != numwritten)
        goto err2;

    if (close(fd) == -1)
        goto err;

    if (touchtime)
    {   struct utimbuf ubuf;

        ubuf.actime = ((struct stat *)touchtime)->st_atime;
        ubuf.modtime = ((struct stat *)touchtime)->st_mtime;
        if (utime(name, &ubuf))
            goto err;
    }
    return 0;

err2:
    close(fd);
    ::remove(name);
err:
    return 1;
#elif _WIN32
    HANDLE h;
    DWORD numwritten;
    char *name;

    name = this->name->toChars();
    h = CreateFileA(name,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,NULL);
    if (h == INVALID_HANDLE_VALUE)
        goto err;

    if (WriteFile(h,buffer,len,&numwritten,NULL) != TRUE)
        goto err2;

    if (len != numwritten)
        goto err2;

    if (touchtime) {
        SetFileTime(h, NULL, NULL, &((WIN32_FIND_DATAA *)touchtime)->ftLastWriteTime);
    }
    if (!CloseHandle(h))
        goto err;
    return 0;

err2:
    CloseHandle(h);
    DeleteFileA(name);
err:
    return 1;
#else
    assert(0);
#endif
}

/*********************************************
 * Append to a file.
 * Returns:
 *      0       success
 */

int File::append()
{
#if POSIX
    return 1;
#elif _WIN32
    HANDLE h;
    DWORD numwritten;
    char *name;

    name = this->name->toChars();
    h = CreateFileA(name,GENERIC_WRITE,0,NULL,OPEN_ALWAYS,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,NULL);
    if (h == INVALID_HANDLE_VALUE)
        goto err;

#if 1
    SetFilePointer(h, 0, NULL, FILE_END);
#else // INVALID_SET_FILE_POINTER doesn't seem to have a definition
    if (SetFilePointer(h, 0, NULL, FILE_END) == INVALID_SET_FILE_POINTER)
        goto err;
#endif

    if (WriteFile(h,buffer,len,&numwritten,NULL) != TRUE)
        goto err2;

    if (len != numwritten)
        goto err2;

    if (touchtime) {
        SetFileTime(h, NULL, NULL, &((WIN32_FIND_DATAA *)touchtime)->ftLastWriteTime);
    }
    if (!CloseHandle(h))
        goto err;
    return 0;

err2:
    CloseHandle(h);
err:
    return 1;
#else
    assert(0);
#endif
}

/*******************************************
 * Return !=0 if file exists.
 *      0:      file doesn't exist
 *      1:      normal file
 *      2:      directory
 */

int File::exists()
{
#if POSIX
    return 0;
#elif _WIN32
    DWORD dw;
    int result;
    char *name;

    name = this->name->toChars();
    if (touchtime)
        dw = ((WIN32_FIND_DATAA *)touchtime)->dwFileAttributes;
    else
        dw = GetFileAttributesA(name);
    if (dw == -1L)
        result = 0;
    else if (dw & FILE_ATTRIBUTE_DIRECTORY)
        result = 2;
    else
        result = 1;
    return result;
#else
    assert(0);
#endif
}

void File::remove()
{
#if POSIX
    int dummy = ::remove(this->name->toChars());
#elif _WIN32
    DeleteFileA(this->name->toChars());
#else
    assert(0);
#endif
}

Files *File::match(char *n)
{
    return match(new FileName(n));
}

Files *File::match(FileName *n)
{
#if POSIX
    return NULL;
#elif _WIN32
    HANDLE h;
    WIN32_FIND_DATAA fileinfo;

    Files *a = new Files();
    const char *c = n->toChars();
    const char *name = n->name();
    h = FindFirstFileA(c,&fileinfo);
    if (h != INVALID_HANDLE_VALUE)
    {
        do
        {
            // Glue path together with name
            char *fn;
            File *f;

            fn = (char *)mem.malloc(name - c + strlen(&fileinfo.cFileName[0]) + 1);
            memcpy(fn, c, name - c);
            strcpy(fn + (name - c), &fileinfo.cFileName[0]);
            f = new File(fn);
            f->touchtime = mem.malloc(sizeof(WIN32_FIND_DATAA));
            memcpy(f->touchtime, &fileinfo, sizeof(fileinfo));
            a->push(f);
        } while (FindNextFileA(h,&fileinfo) != FALSE);
        FindClose(h);
    }
    return a;
#else
    assert(0);
#endif
}

int File::compareTime(File *f)
{
#if POSIX
    return 0;
#elif _WIN32
    if (!touchtime)
        stat();
    if (!f->touchtime)
        f->stat();
    return CompareFileTime(&((WIN32_FIND_DATAA *)touchtime)->ftLastWriteTime, &((WIN32_FIND_DATAA *)f->touchtime)->ftLastWriteTime);
#else
    assert(0);
#endif
}

void File::stat()
{
#if POSIX
    if (!touchtime)
    {
        touchtime = mem.calloc(1, sizeof(struct stat));
    }
#elif _WIN32
    HANDLE h;

    if (!touchtime)
    {
        touchtime = mem.calloc(1, sizeof(WIN32_FIND_DATAA));
    }
    h = FindFirstFileA(name->toChars(),(WIN32_FIND_DATAA *)touchtime);
    if (h != INVALID_HANDLE_VALUE)
    {
        FindClose(h);
    }
#else
    assert(0);
#endif
}

char *File::toChars()
{
    return name->toChars();
}
