// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.file;

import core.stdc.errno, core.stdc.stdio, core.stdc.stdlib, core.stdc.string, core.sys.posix.fcntl, core.sys.posix.sys.types, core.sys.posix.unistd, core.sys.posix.utime, core.sys.windows.windows;
import ddmd.root.array, ddmd.root.filename, ddmd.root.rmem;

version (Windows) alias WIN32_FIND_DATAA = WIN32_FIND_DATA;

struct File
{
    int _ref; // != 0 if this is a reference to someone else's buffer
    ubyte* buffer; // data for our file
    size_t len; // amount of data in buffer[]
    FileName* name; // name of our file

    extern (D) this(const(char)* n)
    {
        _ref = 0;
        buffer = null;
        len = 0;
        name = new FileName(n);
    }

    extern (C++) static File* create(const(char)* n)
    {
        return new File(n);
    }

    /****************************** File ********************************/
    extern (D) this(const(FileName)* n)
    {
        _ref = 0;
        buffer = null;
        len = 0;
        name = cast(FileName*)n;
    }

    extern (C++) ~this()
    {
        if (buffer)
        {
            if (_ref == 0)
                mem.xfree(buffer);
            version (Windows)
            {
                if (_ref == 2)
                    UnmapViewOfFile(buffer);
            }
        }
    }

    extern (C++) char* toChars()
    {
        return name.toChars();
    }

    /*************************************
     */
    extern (C++) bool read()
    {
        if (len)
            return false; // already read the file
        version (Posix)
        {
            size_t size;
            stat_t buf;
            ssize_t numread;
            char* name = this.name.toChars();
            //printf("File::read('%s')\n",name);
            int fd = open(name, O_RDONLY);
            if (fd == -1)
            {
                //printf("\topen error, errno = %d\n",errno);
                goto err1;
            }
            if (!_ref)
                .free(buffer);
            _ref = 0; // we own the buffer now
            //printf("\tfile opened\n");
            if (fstat(fd, &buf))
            {
                printf("\tfstat error, errno = %d\n", errno);
                goto err2;
            }
            size = cast(size_t)buf.st_size;
            buffer = cast(ubyte*).malloc(size + 2);
            if (!buffer)
            {
                printf("\tmalloc error, errno = %d\n", errno);
                goto err2;
            }
            numread = .read(fd, buffer, size);
            if (numread != size)
            {
                printf("\tread error, errno = %d\n", errno);
                goto err2;
            }
            if (close(fd) == -1)
            {
                printf("\tclose error, errno = %d\n", errno);
                goto err;
            }
            len = size;
            // Always store a wchar ^Z past end of buffer so scanner has a sentinel
            buffer[size] = 0; // ^Z is obsolete, use 0
            buffer[size + 1] = 0;
            return false;
        err2:
            close(fd);
        err:
            .free(buffer);
            buffer = null;
            len = 0;
        err1:
            return true;
        }
        else version (Windows)
        {
            DWORD size;
            DWORD numread;
            char* name = this.name.toChars();
            HANDLE h = CreateFileA(name, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, null);
            if (h == INVALID_HANDLE_VALUE)
                goto err1;
            if (!_ref)
                .free(buffer);
            _ref = 0;
            size = GetFileSize(h, null);
            buffer = cast(ubyte*).malloc(size + 2);
            if (!buffer)
                goto err2;
            if (ReadFile(h, buffer, size, &numread, null) != TRUE)
                goto err2;
            if (numread != size)
                goto err2;
            if (!CloseHandle(h))
                goto err;
            len = size;
            // Always store a wchar ^Z past end of buffer so scanner has a sentinel
            buffer[size] = 0; // ^Z is obsolete, use 0
            buffer[size + 1] = 0;
            return 0;
        err2:
            CloseHandle(h);
        err:
            .free(buffer);
            buffer = null;
            len = 0;
        err1:
            return true;
        }
        else
        {
            assert(0);
        }
    }

    /*********************************************
     * Write a file.
     * Returns:
     *      false       success
     */
    extern (C++) bool write()
    {
        version (Posix)
        {
            ssize_t numwritten;
            char* name = this.name.toChars();
            int fd = open(name, O_CREAT | O_WRONLY | O_TRUNC, (6 << 6) | (4 << 3) | 4);
            if (fd == -1)
                goto err;
            numwritten = .write(fd, buffer, len);
            if (len != numwritten)
                goto err2;
            if (close(fd) == -1)
                goto err;
            return false;
        err2:
            close(fd);
            .remove(name);
        err:
            return true;
        }
        else version (Windows)
        {
            DWORD numwritten;
            char* name = this.name.toChars();
            HANDLE h = CreateFileA(name, GENERIC_WRITE, 0, null, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN, null);
            if (h == INVALID_HANDLE_VALUE)
                goto err;
            if (WriteFile(h, buffer, cast(DWORD)len, &numwritten, null) != TRUE)
                goto err2;
            if (len != numwritten)
                goto err2;
            if (!CloseHandle(h))
                goto err;
            return false;
        err2:
            CloseHandle(h);
            DeleteFileA(name);
        err:
            return true;
        }
        else
        {
            assert(0);
        }
    }

    /* Set buffer
     */
    extern (C++) void setbuffer(void* buffer, size_t len)
    {
        this.buffer = cast(ubyte*)buffer;
        this.len = len;
    }

    // delete file
    extern (C++) void remove()
    {
        version (Posix)
        {
            int dummy = .remove(this.name.toChars());
        }
        else version (Windows)
        {
            DeleteFileA(this.name.toChars());
        }
        else
        {
            assert(0);
        }
    }
}
