/**
 * File utilities.
 *
 * Copyright: Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/outbuffer.d, root/_outbuffer.d)
 * Documentation: https://dlang.org/phobos/dmd_root_outbuffer.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/outbuffer.d
 */

module dmd.common.file;

import core.stdc.errno : errno;
import core.stdc.stdio : fprintf, rename, stderr;
import core.stdc.stdlib : exit;
import core.stdc.string : strerror;
import core.sys.windows.winbase;
import core.sys.windows.winnt;

/**
Encapsulated management of a memory-mapped file.

Params:
Datum = the mapped data type: Use a POD of size 1 for read/write mapping
and a `const` version thereof for read-only mapping. Other primitive types
should work, but have not been yet tested.
*/
struct FileMapping(Datum)
{
    static assert(__traits(isPOD, Datum) && Datum.sizeof == 1,
        "Not tested with other data types yet. Add new types with care.");

    version(Posix) enum invalidHandle = -1;
    else version(Windows) enum invalidHandle = INVALID_HANDLE_VALUE;

    // state {
    /// Handle of underlying file
    private auto handle = invalidHandle;
    /// File mapping object needed on Windows
    version(Windows) private HANDLE fileMappingObject = invalidHandle;
    /// Memory-mapped array
    private Datum[] data;
    /// Name of underlying file, zero-terminated
    private const(char)* name;
    // state }

    /**
    Open `filename` and map it in memory. If `Datum` is `const`, opens for
    read-only and maps the content in memory; no error is issued if the file
    does not exist. This makes it easy to treat a non-existing file as empty.

    If `Datum` is mutable, opens for read/write (creates file if it does not
    exist) and fails fatally on any error.

    Due to quirks in `mmap`, if the file is empty, `handle` is valid but `data`
    is `null`. This state is valid and accounted for.

    Params:
    filename = the name of the file to be mapped in memory
    */
    this(const char* filename)
    {
        version (Posix)
        {
            import core.sys.posix.sys.mman;
            import core.sys.posix.fcntl : open, O_CREAT, O_RDONLY, O_RDWR, S_IRGRP, S_IROTH, S_IRUSR, S_IWUSR;

            handle = open(filename, is(Datum == const) ? O_RDONLY : (O_CREAT | O_RDWR),
                S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);

            if (handle == invalidHandle)
            {
                static if (is(Datum == const))
                {
                    // No error, nonexisting file in read mode behaves like an empty file.
                    return;
                }
                else
                {
                    fprintf(stderr, "open(\"%s\") failed: %s\n", filename, strerror(errno));
                    exit(1);
                }
            }

            const size = fileSize(handle);

            if (size > 0 && size != ulong.max && size <= size_t.max)
            {
                auto p = mmap(null, cast(size_t) size, is(Datum == const) ? PROT_READ : PROT_WRITE, MAP_SHARED, handle, 0);
                if (p == MAP_FAILED)
                {
                    fprintf(stderr, "mmap(null, %zu) for \"%s\" failed: %s\n", cast(size_t) size, filename, strerror(errno));
                    exit(1);
                }
                // The cast below will always work because it's gated by the `size <= size_t.max` condition.
                data = cast(Datum[]) p[0 .. cast(size_t) size];
            }
        }
        else version(Windows)
        {
            static if (is(Datum == const))
            {
                enum createFileMode = GENERIC_READ;
                enum openFlags = OPEN_EXISTING;
            }
            else
            {
                enum createFileMode = GENERIC_READ | GENERIC_WRITE;
                enum openFlags = CREATE_ALWAYS;
            }

            handle = CreateFileA(filename, createFileMode, 0, null, openFlags, FILE_ATTRIBUTE_NORMAL, null);
            if (handle == invalidHandle)
            {
                static if (is(Datum == const))
                {
                    return;
                }
                else
                {
                    fprintf(stderr, "CreateFileA() failed for \"%s\": %d\n", filename, GetLastError());
                    exit(1);
                }
            }
            createMapping(filename, fileSize(handle));
        }
        else static assert(0);

        // Save the name for later. Technically there's no need: on Linux one can use readlink on /proc/self/fd/NNN.
        // On BSD and OSX one can use fcntl with F_GETPATH. On Windows one can use GetFileInformationByHandleEx.
        // But just saving the name is simplest, fastest, and most portable...
        import core.stdc.string : strlen;
        name = filename[0 .. filename.strlen() + 1].idup.ptr;
    }

    /**
    Common code factored opportunistically. Windows only. Assumes `handle` is
    already pointing to an opened file. Initializes the `fileMappingObject`
    and `data` members.

    Params:
    filename = the file to be mapped
    size = the size of the file in bytes
    */
    version(Windows) private void createMapping(const char* filename, ulong size)
    {
        assert(size <= size_t.max || size == ulong.max);
        assert(handle != invalidHandle);
        assert(data is null);
        assert(fileMappingObject == invalidHandle);

        if (size == 0 || size == ulong.max)
            return;

        static if (is(Datum == const))
        {
            enum fileMappingFlags = PAGE_READONLY;
            enum mapViewFlags = FILE_MAP_READ;
        }
        else
        {
            enum fileMappingFlags = PAGE_READWRITE;
            enum mapViewFlags = FILE_MAP_WRITE;
        }

        fileMappingObject = CreateFileMappingA(handle, null, fileMappingFlags, 0, 0, null);
        if (!fileMappingObject)
        {
            fprintf(stderr, "CreateFileMappingA(%p) failed for %llu bytes of \"%s\": %d\n",
                handle, size, filename, GetLastError());
            fileMappingObject = invalidHandle;  // by convention always use invalidHandle, not null
            exit(1);
        }
        auto p = MapViewOfFile(fileMappingObject, mapViewFlags, 0, 0, 0);
        if (!p)
        {
            fprintf(stderr, "MapViewOfFile() failed for \"%s\": %d\n", filename, GetLastError());
            exit(1);
        }
        data = cast(Datum[]) p[0 .. cast(size_t) size];
    }

    // Not copyable or assignable (for now).
    @disable this(const FileMapping!Datum rhs);
    @disable void opAssign(const ref FileMapping!Datum rhs);

    /**
    Frees resources associated with this mapping. However, it does not deallocate the name.
    */
    ~this() pure nothrow
    {
        if (!active)
            return;
        fakePure({
            version (Posix)
            {
                import core.sys.posix.sys.mman : munmap;
                import core.sys.posix.unistd : close;

                // Cannot call fprintf from inside a destructor, so exiting silently.

                if (data.ptr && munmap(cast(void*) data.ptr, data.length) != 0)
                {
                    exit(1);
                }
                data = null;
                if (handle != invalidHandle && close(handle) != 0)
                {
                    exit(1);
                }
                handle = invalidHandle;
            }
            else version(Windows)
            {
                if (data.ptr !is null && UnmapViewOfFile(cast(void*) data.ptr) == 0)
                {
                    exit(1);
                }
                data = null;
                if (fileMappingObject != invalidHandle && CloseHandle(fileMappingObject) == 0)
                {
                    exit(1);
                }
                fileMappingObject = invalidHandle;
                if (handle != invalidHandle && CloseHandle(handle) == 0)
                {
                    exit(1);
                }
                handle = invalidHandle;
            }
            else static assert(0);
        });
    }

    /**
    Returns the zero-terminated file name associated with the mapping. Can
    be saved beyond the lifetime of `this`.
    */
    const(char)* filename() const pure @nogc @safe nothrow { return name; }

    /**
    Frees resources associated with this mapping. However, it does not deallocate the name.
    Reinitializes `this` as a fresh object that can be reused.
    */
    void close()
    {
        __dtor();
        handle = invalidHandle;
        version(Windows) fileMappingObject = invalidHandle;
        data = null;
        name = null;
    }

    /**
    Deletes the underlying file and frees all resources associated.
    Reinitializes `this` as a fresh object that can be reused.

    This function does not abort if the file cannot be deleted, but does print
    a message on `stderr` and returns `false` to the caller. The underlying
    rationale is to give the caller the option to continue execution if
    deleting the file is not important.

    Returns: `true` iff the file was successfully deleted. If the file was not
    deleted, prints a message to `stderr` and returns `false`.
    */
    static if (!is(Datum == const))
    bool discard()
    {
        // Truncate file to zero so unflushed buffers are not flushed unnecessarily.
        resize(0);
        auto deleteme = name;
        close();
        // In-memory resource freed, now get rid of the underlying temp file.
        version(Posix)
        {
            import core.sys.posix.unistd : unlink;
            if (unlink(deleteme) != 0)
            {
                fprintf(stderr, "unlink(\"%s\") failed: %s\n", filename, strerror(errno));
                return false;
            }
        }
        else version(Windows)
        {
            import core.sys.windows.winbase;
            if (DeleteFileA(deleteme) == 0)
            {
                fprintf(stderr, "DeleteFileA error %d\n", GetLastError());
                return false;
            }
        }
        else static assert(0);
        return true;
    }

    /**
    Queries whether `this` is currently associated with a file.

    Returns: `true` iff there is an active mapping.
    */
    bool active() const pure @nogc nothrow
    {
        return handle !is invalidHandle;
    }

    /**
    Queries the length of the file associated with this mapping.  If not
    active, returns 0.

    Returns: the length of the file, or 0 if no file associated.
    */
    size_t length() const pure @nogc @safe nothrow { return data.length; }

    /**
    Get a slice to the contents of the entire file.

    Returns: the contents of the file. If not active, returns the `null` slice.
    */
    auto opSlice() pure @nogc @safe nothrow { return data; }

    /**
    Resizes the file and mapping to the specified `size`.

    Params:
    size = new length requested
    */
    static if (!is(Datum == const))
    void resize(size_t size) pure
    {
        assert(handle != invalidHandle);
        fakePure({
            version(Posix)
            {
                import core.sys.posix.unistd : ftruncate;
                import core.sys.posix.sys.mman;

                if (data.length)
                {
                    assert(data.ptr, "Corrupt memory mapping");
                    // assert(0) here because it would indicate an internal error
                    munmap(cast(void*) data.ptr, data.length) == 0 || assert(0);
                    data = null;
                }
                if (ftruncate(handle, size) != 0)
                {
                    fprintf(stderr, "ftruncate() failed for \"%s\": %s\n", filename, strerror(errno));
                    exit(1);
                }
                if (size > 0)
                {
                    auto p = mmap(null, size, PROT_WRITE, MAP_SHARED, handle, 0);
                    if (cast(ssize_t) p == -1)
                    {
                        fprintf(stderr, "mmap() failed for \"%s\": %s\n", filename, strerror(errno));
                        exit(1);
                    }
                    data = cast(Datum[]) p[0 .. size];
                }
            }
            else version(Windows)
            {
                // Per documentation, must unmap first.
                if (data.length > 0 && UnmapViewOfFile(cast(void*) data.ptr) == 0)
                {
                    fprintf(stderr, "UnmapViewOfFile(%p) failed for memory mapping of \"%s\": %d\n",
                        data.ptr, filename, GetLastError());
                    exit(1);
                }
                data = null;
                if (fileMappingObject != invalidHandle && CloseHandle(fileMappingObject) == 0)
                {
                    fprintf(stderr, "CloseHandle() failed for memory mapping of \"%s\": %d\n", filename, GetLastError());
                    exit(1);
                }
                fileMappingObject = invalidHandle;
                LARGE_INTEGER biggie;
                biggie.QuadPart = size;
                if (SetFilePointerEx(handle, biggie, null, FILE_BEGIN) == 0 || SetEndOfFile(handle) == 0)
                {
                    fprintf(stderr, "SetFilePointer() failed for \"%s\": %d\n", filename, GetLastError());
                    exit(1);
                }
                createMapping(name, size);
            }
            else static assert(0);
        });
    }

    /**
    Unconditionally and destructively moves the underlying file to `filename`.
    If the operation succeds, returns true. Upon failure, prints a message to
    `stderr` and returns `false`.

    Params: filename = zero-terminated name of the file to move to.

    Returns: `true` iff the operation was successful.
    */
    bool moveToFile(const char* filename)
    {
        auto oldname = name;

        close();
        // Rename the underlying file to the target, no copy necessary.
        version(Posix)
        {
            if (.rename(oldname, filename) != 0)
            {
                fprintf(stderr, "rename(\"%s\", \"%s\") failed: %s\n", oldname, filename, strerror(errno));
                return false;
            }
        }
        else version(Windows)
        {
            import core.sys.windows.winbase;
            if (MoveFileExA(oldname, filename, MOVEFILE_REPLACE_EXISTING) == 0)
            {
                fprintf(stderr, "MoveFileExA(\"%s\", \"%s\") failed: %d\n", oldname, filename, GetLastError());
                return false;
            }
        }
        else static assert(0);
        return true;
    }
}

/**
Runs a non-pure function or delegate as pure code. Use with caution.

Params:
fun = the delegate to run, usually inlined: `fakePure({ ... });`

Returns: whatever `fun` returns.
*/
private auto ref fakePure(F)(scope F fun) pure
{
    mixin("alias PureFun = " ~ F.stringof ~ " pure;");
    return (cast(PureFun) fun)();
}

// Feel free to make these public if used elsewhere.
/**
Size of a file in bytes.
Params: fd = file handle
Returns: file size in bytes, or `ulong.max` on any error.
*/
version (Posix)
private ulong fileSize(int fd)
{
    import core.sys.posix.sys.stat;
    stat_t buf;
    if (fstat(fd, &buf) == 0)
        return buf.st_size;
    return ulong.max;
}

/// Ditto
version (Windows)
private ulong fileSize(HANDLE fd)
{
    ulong result;
    if (GetFileSizeEx(fd, cast(LARGE_INTEGER*) &result) == 0)
        return result;
    return ulong.max;
}
