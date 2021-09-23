/**
 * Read a file from disk and store it in memory.
 *
 * Copyright: Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/file.d, root/_file.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_file.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/file.d
 */

module dmd.root.file;

import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string : strerror;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.windows.winbase;
import core.sys.windows.winnt;
import dmd.root.filename;
import dmd.root.rmem;
import dmd.root.string;

/// Owns a (rmem-managed) file buffer.
struct FileBuffer
{
    ubyte[] data;

    this(this) @disable;

    ~this() pure nothrow
    {
        mem.xfree(data.ptr);
    }

    /// Transfers ownership of the buffer to the caller.
    ubyte[] extractSlice() pure nothrow @nogc @safe
    {
        auto result = data;
        data = null;
        return result;
    }

    extern (C++) static FileBuffer* create() pure nothrow @safe
    {
        return new FileBuffer();
    }
}

///
struct File
{
    ///
    static struct ReadResult
    {
        bool success;
        FileBuffer buffer;

        /// Transfers ownership of the buffer to the caller.
        ubyte[] extractSlice() pure nothrow @nogc @safe
        {
            return buffer.extractSlice();
        }

        /// ditto
        /// Include the null-terminator at the end of the buffer in the returned array.
        ubyte[] extractDataZ() @nogc nothrow pure
        {
            auto result = buffer.extractSlice();
            return result.ptr[0 .. result.length + 1];
        }
    }

nothrow:
    /// Read the full content of a file.
    extern (C++) static ReadResult read(const(char)* name)
    {
        return read(name.toDString());
    }

    /// Ditto
    static ReadResult read(const(char)[] name)
    {
        ReadResult result;

        version (Posix)
        {
            size_t size;
            stat_t buf;
            ssize_t numread;
            //printf("File::read('%s')\n",name);
            int fd = name.toCStringThen!(slice => open(slice.ptr, O_RDONLY));
            if (fd == -1)
            {
                //printf("\topen error, errno = %d\n",errno);
                return result;
            }
            //printf("\tfile opened\n");
            if (fstat(fd, &buf))
            {
                perror("\tfstat error");
                close(fd);
                return result;
            }
            size = cast(size_t)buf.st_size;
            ubyte* buffer = cast(ubyte*)mem.xmalloc_noscan(size + 4);
            numread = .read(fd, buffer, size);
            if (numread != size)
            {
                perror("\tread error");
                goto err2;
            }
            if (close(fd) == -1)
            {
                perror("\tclose error");
                goto err;
            }
            // Always store a wchar ^Z past end of buffer so scanner has a sentinel
            buffer[size] = 0; // ^Z is obsolete, use 0
            buffer[size + 1] = 0;
            buffer[size + 2] = 0; //add two more so lexer doesnt read pass the buffer
            buffer[size + 3] = 0;

            result.success = true;
            result.buffer.data = buffer[0 .. size];
            return result;
        err2:
            close(fd);
        err:
            mem.xfree(buffer);
            return result;
        }
        else version (Windows)
        {
            DWORD size;
            DWORD numread;

            // work around Windows file path length limitation
            // (see documentation for extendedPathThen).
            HANDLE h = name.extendedPathThen!
                (p => CreateFileW(p.ptr,
                                  GENERIC_READ,
                                  FILE_SHARE_READ,
                                  null,
                                  OPEN_EXISTING,
                                  FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
                                  null));
            if (h == INVALID_HANDLE_VALUE)
                return result;
            size = GetFileSize(h, null);
            ubyte* buffer = cast(ubyte*)mem.xmalloc_noscan(size + 4);
            if (ReadFile(h, buffer, size, &numread, null) != TRUE)
                goto err2;
            if (numread != size)
                goto err2;
            if (!CloseHandle(h))
                goto err;
            // Always store a wchar ^Z past end of buffer so scanner has a sentinel
            buffer[size] = 0; // ^Z is obsolete, use 0
            buffer[size + 1] = 0;
            buffer[size + 2] = 0; //add two more so lexer doesnt read pass the buffer
            buffer[size + 3] = 0;
            result.success = true;
            result.buffer.data = buffer[0 .. size];
            return result;
        err2:
            CloseHandle(h);
        err:
            mem.xfree(buffer);
            return result;
        }
        else
        {
            assert(0);
        }
    }

    /// Write a file, returning `true` on success.
    extern (D) static bool write(const(char)* name, const void[] data)
    {
        version (Posix)
        {
            ssize_t numwritten;
            int fd = open(name, O_CREAT | O_WRONLY | O_TRUNC, (6 << 6) | (4 << 3) | 4);
            if (fd == -1)
                goto err;
            numwritten = .write(fd, data.ptr, data.length);
            if (numwritten != data.length)
                goto err2;
            if (close(fd) == -1)
                goto err;
            return true;
        err2:
            close(fd);
            .remove(name);
        err:
            return false;
        }
        else version (Windows)
        {
            DWORD numwritten; // here because of the gotos
            const nameStr = name.toDString;
            // work around Windows file path length limitation
            // (see documentation for extendedPathThen).
            HANDLE h = nameStr.extendedPathThen!
                (p => CreateFileW(p.ptr,
                                  GENERIC_WRITE,
                                  0,
                                  null,
                                  CREATE_ALWAYS,
                                  FILE_ATTRIBUTE_NORMAL | FILE_FLAG_SEQUENTIAL_SCAN,
                                  null));
            if (h == INVALID_HANDLE_VALUE)
                goto err;

            if (WriteFile(h, data.ptr, cast(DWORD)data.length, &numwritten, null) != TRUE)
                goto err2;
            if (numwritten != data.length)
                goto err2;
            if (!CloseHandle(h))
                goto err;
            return true;
        err2:
            CloseHandle(h);
            nameStr.extendedPathThen!(p => DeleteFileW(p.ptr));
        err:
            return false;
        }
        else
        {
            static assert(0);
        }
    }

    ///ditto
    extern(D) static bool write(const(char)[] name, const void[] data)
    {
        return name.toCStringThen!((fname) => write(fname.ptr, data));
    }

    /// ditto
    extern (C++) static bool write(const(char)* name, const(void)* data, size_t size)
    {
        return write(name, data[0 .. size]);
    }

    /// Delete a file.
    extern (C++) static void remove(const(char)* name)
    {
        version (Posix)
        {
            .remove(name);
        }
        else version (Windows)
        {
            name.toDString.extendedPathThen!(p => DeleteFileW(p.ptr));
        }
        else
        {
            static assert(0);
        }
    }

    /***************************************************
     * Update file
     *
     * If the file exists and is identical to what is to be written,
     * merely update the timestamp on the file.
     * Otherwise, write the file.
     *
     * The idea is writes are much slower than reads, and build systems
     * often wind up generating identical files.
     * Params:
     *  name = name of file to update
     *  data = updated contents of file
     * Returns:
     *  `true` on success
     */
    extern (D) static bool update(const(char)* namez, const void[] data)
    {
        enum log = false;
        if (log) printf("update %s\n", namez);

        if (data.length != File.size(namez))
            return write(namez, data);               // write new file

        if (log) printf("same size\n");

        /* The file already exists, and is the same size.
         * Read it in, and compare for equality.
         */
        //if (FileMapping!(const ubyte)(namez)[] != data[])
            return write(namez, data); // contents not same, so write new file
        //if (log) printf("same contents\n");

        /* Contents are identical, so set timestamp of existing file to current time
         */
        //return touch(namez);
    }

    ///ditto
    extern(D) static bool update(const(char)[] name, const void[] data)
    {
        return name.toCStringThen!(fname => update(fname.ptr, data));
    }

    /// ditto
    extern (C++) static bool update(const(char)* name, const(void)* data, size_t size)
    {
        return update(name, data[0 .. size]);
    }

    /// Touch a file to current date
    static bool touch(const char* namez)
    {
        version (Windows)
        {
            FILETIME ft = void;
            SYSTEMTIME st = void;
            GetSystemTime(&st);
            SystemTimeToFileTime(&st, &ft);

            import core.stdc.string : strlen;

            // get handle to file
            HANDLE h = namez[0 .. namez.strlen()].extendedPathThen!(p => CreateFile(p.ptr,
                FILE_WRITE_ATTRIBUTES, FILE_SHARE_READ | FILE_SHARE_WRITE,
                null, OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL, null));
            if (h == INVALID_HANDLE_VALUE)
                return false;

            const f = SetFileTime(h, null, null, &ft); // set last write time

            if (!CloseHandle(h))
                return false;

            return f != 0;
        }
        else version (Posix)
        {
            import core.sys.posix.utime;
            return utime(namez, null) == 0;
        }
        else
            static assert(0);
    }

    /// Size of a file in bytes.
    /// Params: namez = null-terminated filename
    /// Returns: `ulong.max` on any error, the length otherwise.
    static ulong size(const char* namez)
    {
        version (Posix)
        {
            stat_t buf;
            if (stat(namez, &buf) == 0)
                return buf.st_size;
        }
        else version (Windows)
        {
            const nameStr = namez.toDString();
            import core.sys.windows.windows;
            WIN32_FILE_ATTRIBUTE_DATA fad = void;
            // Doesn't exist, not a regular file, different size
            if (nameStr.extendedPathThen!(p => GetFileAttributesExW(p.ptr, GET_FILEEX_INFO_LEVELS.GetFileExInfoStandard, &fad)) != 0)
                return (ulong(fad.nFileSizeHigh) << 32UL) | fad.nFileSizeLow;
        }
        else static assert(0);
        // Error cases go here.
        return ulong.max;
    }
}

