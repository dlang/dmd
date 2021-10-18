/**
 * Cache the contents from files read from disk into memory.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/filecache.d, filecache.d)
 * Documentation:  https://dlang.org/phobos/dmd_filecache.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/filecache.d
 */

module dmd.filecache;

import dmd.root.stringtable;
import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;

import core.stdc.stdio;

/**
A line-by-line representation of a $(REF File, dmd,root,file).
*/
class FileAndLines
{
    FileName* file;
    FileBuffer* buffer;
    const(char[])[] lines;

  nothrow:

    /**
    File to read and split into its lines.
    */
    this(const(char)[] filename)
    {
        file = new FileName(filename);
        readAndSplit();
    }

    // Read a file and split the file buffer linewise
    private void readAndSplit()
    {
        auto readResult = File.read(file.toChars());
        // FIXME: check success
        // take ownership of buffer
        buffer = new FileBuffer(readResult.extractSlice());
        ubyte* buf = buffer.data.ptr;
        // slice into lines
        while (*buf)
        {
            auto prevBuf = buf;
            for (; *buf != '\n' && *buf != '\r'; buf++)
            {
                if (!*buf)
                    break;
            }
            // handle Windows line endings
            if (*buf == '\r' && *(buf + 1) == '\n')
                buf++;
            lines ~= cast(const(char)[]) prevBuf[0 .. buf - prevBuf];
            buf++;
        }
    }

    void destroy()
    {
        if (file)
        {
            file.destroy();
            file = null;
            buffer.destroy();
            buffer = null;
            lines.destroy();
            lines = null;
        }
    }

    ~this()
    {
        destroy();
    }
}

/**
A simple file cache that can be used to avoid reading the same file multiple times.
It stores its cached files as $(LREF FileAndLines)
*/
extern(C++) struct FileCache
{
    private StringTable!(FileAndLines) files;

  nothrow:

    /**
    Add or get a file from the file cache.
    If the file isn't part of the cache, it will be read from the filesystem.
    If the file has been read before, the cached file object will be returned

    Params:
        file = file to load in (or get from) the cache

    Returns: a $(LREF FileAndLines) object containing a line-by-line representation of the requested file
    */
    extern(D) FileAndLines addOrGetFile(const(char)[] file)
    {
        if (auto payload = files.lookup(file))
        {
            if (payload !is null)
                return payload.value;
        }

        auto lines = new FileAndLines(file);
        files.insert(file, lines);
        return lines;
    }

    __gshared fileCache = FileCache();

    // Initializes the global FileCache singleton
    extern(C++) static __gshared void _init()
    {
        fileCache.initialize();
    }

    extern(D) void initialize()
    {
        files._init();
    }

    extern(D) void deinitialize()
    {
        foreach (sv; files)
            sv.destroy();
        files.reset();
    }
}
