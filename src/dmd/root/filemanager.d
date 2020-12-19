/**
 * Read a file from disk and store it in memory.
 *
 * Copyright: Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/filemanager.d, root/_filemanager.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_filemanager.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/filemanager.d
 */

module dmd.root.filemanager;

import dmd.root.stringtable : StringTable;
import dmd.root.file : File, FileBuffer;
import dmd.root.filename : FileName;
import dmd.dmodule : getFilename, lookForSourceFile;
import dmd.identifier;
import dmd.arraytypes;

struct FileManager
{
    private StringTable!(FileBuffer*) files;

    void _init()
    {
        files._init();
    }

    /**
     * Looks up the given filename in memory.
     *
     * Returns: the loaded source file if it was found in memory,
     *      otherwise `null`
     */
    FileBuffer* opIndex(const(FileName) filename)
    {
        auto val = files.lookup(filename.toString);
        return val == null ? null : val.value;
    }

    /**
     * Loads the source file with the given filename either from memory or disk.
     *
     * It will look for the following cases:
     * * The actual given filename
     * * The filename with the `.d` or `.di` extension added
     * * The filename as a directory with a containing `package.d` or
     *      `package.di` file
     *
     * Returns: the loaded source file if it was found in memory or on disk,
     *      otherwise `null`
     */
    FileBuffer* loadSourceFile(FileName filename)
    {
        const name = filename.toString;
        auto res = FileName.exists(name);

        // File exists and is not a directory
        if (res == 1)
            return readToFileBuffer(filename.toString);

        const completeName = lookForSourceFile(filename.toString);
        if (!completeName)
            return null;

        return readToFileBuffer(completeName);
    }

    /**
     * Loads the source file identified by the `packages` chain of identifiers
     * either from memory or disk.
     *
     * Returns: the loaded source file if it was found in memory or on disk,
     *      otherwise `null`
     */
    FileBuffer* loadSourceFile(Identifiers* packages, Identifier ident)
    {
        // Build module filename by turning:
        //  foo.bar.baz
        // into:
        //  foo\bar\baz
        const(char)[] filename = getFilename(packages, ident);
        // Look for the source file
        const result = lookForSourceFile(filename);
        if (result)
            filename = result;

        // read this file before
        auto val = files.lookup(filename);
        if (val)
            return val.value;

        if (FileName.exists(filename) != 1)
            return null;

        return readToFileBuffer(filename);
    }

    private FileBuffer* readToFileBuffer(const(char)[] filename)
    {
        auto readResult = File.read(filename);
        FileBuffer* fb = FileBuffer.create();
        fb.data = readResult.extractSlice();

        addPair(FileName(filename), fb);
        return fb;
    }

    /**
     * Adds or updates a FileName - FileBuffer pair
     *
     * Returns: The previous FileBuffer or null
     */

    FileBuffer* addPair(FileName filename, FileBuffer* filebuffer)
    {
        auto val = files.replace(filename.toString, filebuffer);
        return val == null ? null : val.value;
    }

}