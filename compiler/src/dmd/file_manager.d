/**
 * Read a file from disk and store it in memory.
 *
 * Copyright: Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/file_manager.d, _file_manager.d)
 * Documentation:  https://dlang.org/phobos/dmd_file_manager.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/file_manager.d
 */

module dmd.file_manager;

import core.stdc.stdio;
import core.stdc.string;

import dmd.common.file;
import dmd.common.outbuffer;
import dmd.root.array;
import dmd.root.stringtable : StringTable;
import dmd.root.file : File, Buffer;
import dmd.root.filename : FileName, isDirSeparator;
import dmd.root.rmem;
import dmd.root.string : toDString;
import dmd.errors;
import dmd.errorsink;
import dmd.globals;
import dmd.identifier;
import dmd.location;

enum package_d  = "package." ~ mars_ext;
enum package_di = "package." ~ hdr_ext;

/// Returns: whether a file with `name` is a special "package.d" module
bool isPackageFileName(scope FileName fileName) nothrow
{
    return FileName.equals(fileName.name, package_d) || FileName.equals(fileName.name, package_di);
}

// A path stack that allows one to go up and down the path using directory
// separators. `cur` is the current path, `up` goes up one path, `down` goes
// down one path. if `up` or `down` return false, there are no further paths.
private struct PathStack
{
    private const(char)[] path;
    private size_t pos;

    @safe @nogc nothrow pure:

    this(const(char)[] p)
    {
        path = p;
        pos = p.length;
    }

    const(char)[] cur()
    {
        return path[0 .. pos];
    }

    bool up()
    {
        if (pos == 0)
            return false;
        while (--pos != 0)
            if (isDirSeparator(path[pos]))
                return true;
        return false;
    }

    bool down()
    {
        if (pos == path.length)
            return false;
        while (++pos != path.length)
            if (isDirSeparator(path[pos]))
                return true;
        return false;
    }
}

enum DIR : ubyte
{
    none,     // path does not exist
    disk,     // path exists on the disk
    archive,  // path exists in the archive
}

/***************************
 * Cache path lookups so the operating system
 * is only consulted once for each path.
 */
private struct PathCache
{
    /* for filespec "a/b/c/d.ext"
     * a b and c are directories, a, a/b, a/b/c are paths.
     */

    StringTable!(DIR) pathStatus;   // cached result of does a path exist or not

  nothrow:

    /**
     * Determine if the path part of path/filename exists.
     * Cache the results for the path and each left-justified subpath of the path.
     * Params:
     *  filespec = path/filename
     *  fileManager = where the caches are
     * Returns:
     *  DIR.none if path does not exist, DIR.disk if it exists on disk, DIR.archive if in archive
     */
    DIR pathExists(const(char)[] filespec, FileManager fileManager) nothrow
    {
        /* look for the longest leftmost parent path that is cached
         * by starting at the right and working to the left
         */
        DIR exists = DIR.disk;
        bool inArchive = false;
        auto st = PathStack(filespec);
        while (st.up) {
            if (auto cached = pathStatus.lookup(st.cur)) {
                if (cached.value == DIR.archive)
                    inArchive = true;
                exists = cached.value;
                break;
            }
        }
        /* found a parent path that is cached (or reached the left end of the path).
         * Now move right caching the results of those directories.
         * Once a directory is found to not exist, all the directories
         * to the right of it do not exist
         */
        while (st.down) {
            if (exists == DIR.none)
                pathStatus.insert(st.cur, DIR.none);
            else
            {
                //printf("pathStatus.insert %.*s\n", cast(int)st.cur.length, st.cur.ptr);
                //printf("pathStatus.insert %s\n", st.cur.ptr);
                //printf("FileName.exists() %d\n", FileName.exists(st.cur.ptr));
                if (inArchive)
                {
                    auto cached = pathStatus.lookup(st.cur);
                    if (cached)
                        exists = cached.value;
                    else
                    {
                        pathStatus.insert(st.cur, DIR.none);
                        exists = DIR.none;
                    }
                }
                else
                {
                    auto cached = pathStatus.insert(st.cur, FileName.exists(st.cur) == 2 ? DIR.disk : DIR.none);
                    if (cached)
                        exists = cached.value;
                    else
                        exists = DIR.disk;
                }
            }
        }

        return exists;
    }

    /**
     * Add each path in filespec to the pathStatus cache, if it is not already there
     * The filename is skipped.
     * Mark each path as either DIR.disk or DIR.archive.
     * Params:
     *  filespec = path/filename
     *  dir = DIR.disk or DIR.archive
     */
    void addPath(const(char)[] filespec, DIR dir) nothrow
    {
        /* look for the longest leftmost parent path
         * by starting at the right and working to the left
         */
        auto st = PathStack(filespec);
        while (st.up)
        {
            if (auto cached = pathStatus.lookup(st.cur))
            {
                if (cached.value)   // subpath exists
                    break;          // assume any more to the left also exist
            }
            pathStatus.insert(st.cur, dir);
        }
    }

    /**
     * Ask if path ends in a directory.
     * Cache result for speed.
     * Params:
     *  path = a path
     * Returns:
     *  DIR
     */
    DIR isExistingPath(const char[] path)
    {
        auto cached = pathStatus.lookup(path);
        if (!cached)
            cached = pathStatus.insert(path, FileName.exists(path) == 2 ? DIR.disk : DIR.none);
        return cached.value;
    }
}

/**************************************************************
 */

final class FileManager
{
    private StringTable!(const(ubyte)[]) files;  // contents of files indexed by file name

    private PathCache pathCache;

    private bool useSourceArchive;         // use .sar files if they exist

    ///
    public this() nothrow
    {
        this.files._init();
        this.pathCache.pathStatus._init();
    }

nothrow:

    /**********************************
     * Set useSourceArchive flag
     * Params:
     *  useSourceArchive = value to set it to
     */
    public void setUseSourceArchive(bool useSourceArchive) nothrow
    {
        //printf("setUseSourceArchive: %d\n", useSourceArchive);
        this.useSourceArchive = useSourceArchive;
    }

    /********************************************
    * Look for the source file if it's different from filename.
    * Look for .di, .d, directory, along each path.
    * Does not open the file.
    * Params:
    *      filename = as supplied by the user
    *      paths = paths to look for filename
    * Returns:
    *      the found file name or
    *      `null` if it is not different from filename.
    */
    const(char)[] lookForSourceFile(const char[] filename, const char*[] paths)
    {
        //printf("lookForSourceFile(`%.*s`)\n", cast(int)filename.length, filename.ptr);
        /* Search along paths[] for .di file, then .d file.
        */

        /******************
         * Check if file exists in the source archive or on disk.
         * Params:
         *      filename = fqn of file
         *      dir = DIR
         * Returns:
         *      true if it exists
         */
        bool isFileExisting(const char[] filename, DIR dir)
        {
            if (dir == DIR.archive)
                return files.lookup(filename) != null;
            else
                return files.lookup(filename) || FileName.exists(filename) == 1;
        }

        // see if we should check for the module locally.
        DIR dirLocal = pathCache.pathExists(filename, this);
        const sdi = FileName.forceExt(filename, hdr_ext);
        if (dirLocal != DIR.none && isFileExisting(sdi, dirLocal))
            return sdi;
        scope(exit) FileName.free(sdi.ptr);

        const sd = FileName.forceExt(filename, mars_ext);
        // Special file name representing `stdin`, always assume its presence
        if (sd == "__stdin.d")
            return sd;
        if (dirLocal && isFileExisting(sd, dirLocal))
            return sd;
        scope(exit) FileName.free(sd.ptr);

        if (dirLocal)
        {
            if (pathCache.isExistingPath(filename))
            {
                /* The filename exists but it's a directory.
                 * Therefore, the result should be: filename/package.d
                 * iff filename/package.d is a file
                 */
                const ni = FileName.combine(filename, package_di);
                if (isFileExisting(ni, dirLocal))
                    return ni;
                FileName.free(ni.ptr);

                const n = FileName.combine(filename, package_d);
                if (isFileExisting(n, dirLocal))
                    return n;
                FileName.free(n.ptr);
            }
        }

        // What about .c and .i files?
        if (FileName.absolute(filename))
            return null;
        if (!paths.length)
            return null;

        foreach (path; paths)
        {
            //printf("path: %s\n", path);
            const p = path.toDString();
            const(char)[] ndi = FileName.combine(p, sdi);
            //printf("ndi: %.*s\n", cast(int)ndi.length, ndi.ptr);

            DIR dir = pathCache.pathExists(ndi, this);
            //printf("dir: %d\n", dir);
            if (dir == DIR.none) {
                FileName.free(ndi.ptr);
                continue; // no need to check for anything else.
            }
            if (isFileExisting(ndi, dir)) {
                return ndi;
            }
            FileName.free(ndi.ptr);

            const(char)[] nd = FileName.combine(p, sd);
            //printf("nd: %.*s\n", cast(int)nd.length, nd.ptr);
            if (isFileExisting(nd, dir)) {
                return nd;
            }
            FileName.free(nd.ptr);

            /* Look for path/FileName/package.di, then path/FileName/package.d
             */
            const(char)[] np = FileName.combine(p, FileName.sansExt(filename));
            scope(exit) FileName.free(np.ptr);

            if (auto val = pathCache.isExistingPath(np))
            {
                const npdi = FileName.combine(np, package_di);
                if (isFileExisting(npdi, val))
                    return npdi;
                FileName.free(npdi.ptr);

                const npd = FileName.combine(np, package_d);
                if (isFileExisting(npd, val))
                    return npd;
                FileName.free(npd.ptr);
            }
        }

        /* ImportC: No D modules found, now repeat search for .i file, then .c file.
         * Same as code above, sans the package search.
         */
        const si = FileName.forceExt(filename, i_ext);
        if (dirLocal != DIR.none && isFileExisting(si, dirLocal))
            return si;
        scope(exit) FileName.free(si.ptr);

        const sc = FileName.forceExt(filename, c_ext);
        if (dirLocal != DIR.none && isFileExisting(sc, dirLocal))
            return sc;
        scope(exit) FileName.free(sc.ptr);

        foreach (path; paths)
        {
            const p = path.toDString();

            const(char)[] ni = FileName.combine(p, si);
            DIR dir = pathCache.pathExists(ni, this);
            if (dir == DIR.none) {
                FileName.free(ni.ptr);
                continue; // no need to check for anything else.
            }

            if (isFileExisting(ni, dir)) {
                return ni;
            }
            FileName.free(ni.ptr);

            const(char)[] nc = FileName.combine(p, sc);
            if (isFileExisting(nc, dir))
                return nc;
            FileName.free(nc.ptr);
        }
        return null;
    }

    /**
     * Retrieve the cached contents of the file given by `filename`.
     * If the file has not been read before, read it and add the contents
     * to the file cache.
     * Params:
     *  filename = the name of the file
     * Returns:
     *  the contents of the file, or `null` if it could not be read or was empty
     */
    const(ubyte)[] getFileContents(FileName filename)
    {
        const name = filename.toString;
        if (auto val = files.lookup(name))      // if `name` is cached
        {
            //printf("File.read() cached %.*s, %p[%d]\n", cast(int)name.length, name.ptr, val.value.ptr, cast(int)val.value.length);
            return val.value;                   // return its contents
        }

        OutBuffer buf;
        if (name == "__stdin.d")                // special name for reading from stdin
        {
            if (readFromStdin(buf))
                fatal();
        }
        else
        {
            if (FileName.exists(name) != 1) // if not an ordinary file
                return null;

            //printf("File.read() %.*s\n", cast(int)name.length, name.ptr);
            if (File.read(name, buf))
                return null;        // failed
        }

        buf.write32(0);         // terminating dchar 0

        const length = buf.length;
        const ubyte[] fb = cast(ubyte[])(buf.extractSlice()[0 .. length - 4]);
        if (files.insert(name, fb) is null)
            assert(0, "Insert after lookup failure should never return `null`");

        return fb;
    }

    /**
     * Adds the contents of a file to the table.
     * Params:
     *  filename = name of the file
     *  buffer = contents of the file
     * Returns:
     *  the buffer added, or null
     */
    const(ubyte)[] add(FileName filename, const(ubyte)[] buffer)
    {
        auto val = files.insert(filename.toString, buffer);
        return val == null ? null : val.value;
    }

    /**
     * Add the file's name and contents to the cache.
     * Params:
     *  fileName = fqn of the file
     *  contents = the file contents
     */
    void addSarFileNameAndContents(const(char)[] fileName, const(ubyte)[] contents)
    {
        //printf("addSarFileNameAndContents() %.*s\n", cast(int)fileName.length, fileName.ptr);
        /* Unseen subpaths will be within a .sar archive
         */
        pathCache.addPath(fileName, DIR.archive);
        files.insert(fileName, contents);
    }
}

private bool readFromStdin(ref OutBuffer sink) nothrow
{
    import core.stdc.stdio;
    import dmd.errors;

    enum BufIncrement = 128 * 1024;

    for (size_t j; 1; ++j)
    {
        char[] buffer = sink.allocate(BufIncrement);

        // Fill up buffer
        size_t filled = 0;
        do
        {
            filled += fread(buffer.ptr + filled, 1, buffer.length - filled, stdin);
            if (ferror(stdin))
            {
                import core.stdc.errno;
                error(Loc.initial, "cannot read from stdin, errno = %d", errno);
                return true;
            }
            if (feof(stdin)) // successful completion
            {
                sink.setsize(j * BufIncrement + filled);
                return false;
            }
        } while (filled < BufIncrement);
    }

    assert(0);
}

/*************************************************
 * Look along paths[] for archive files.
 * For each one found, add its contents to the path and file caches.
 */
void findAllArchives(FileManager fileManager, const char*[] paths)
{
    if (!fileManager.useSourceArchive)
        return;

    const(char)[][1] exts = [ sar_ext ];

    foreach (path; paths)
    {
        //printf("path: %s\n", path);
        const(char)[] spath = path[0 .. strlen(path)];

        // Remove any trailing separator
        if (spath.length)
        {
            const c = spath[spath.length - 1];
            if (c == '/' || c == '\\')
                spath = spath[0 .. $ - 1];
        }

        void arSink(const(char)[] archiveFile)
        {
            enum log = false;
            if (log) printf("arSink() %.*s\n", cast(int)archiveFile.length, archiveFile.ptr);
            readSourceArchive(fileManager, spath, FileName.name(archiveFile), null, global.errorSink, global.params.v.verbose);
        }

        findFiles(path, exts, false, &arSink);
    }
}

/********************************************
 * Read all the modules, and build one giant cache file out of them.
 * Params:
 *      pathPackage = the path/package to build a cache file for
 * Returns:
 *      true = failed
 *      false = success
 */
bool writeSourceArchive(const(char)[] pathPackage)
{
    enum log = false;
    if (log) printf("writeSourceArchive() %.*s\n", cast(int)pathPackage.length, pathPackage.ptr);

    const(char)[] name = FileName.name(pathPackage);
    const size_t nameStart = pathPackage.length - name.length;

    Array!(const(char)*) fileNames;

    void accumulate(scope const(char)[] filename) nothrow
    {
        if (log) printf("%.*s\n", cast(int)filename.length, filename.ptr);
        fileNames.push(xarraydup(filename).ptr);
    }

    immutable string[4] exts = ["d", "di", "c", "i"];   // archive files with these extensions

    const(char)[] dir_path = xarraydup(pathPackage);

    if (findFiles(dir_path.ptr, exts, true, &accumulate))
        return true;

    OutBuffer ar;  // ar will hold the contents of the archive file

    SrcArchiveHeader srcArchiveHeader;
    srcArchiveHeader.contentsOffset = cast(uint)SrcArchiveHeader.sizeof;
    srcArchiveHeader.contentsLength = cast(uint)fileNames.length;

    ar.write(&srcArchiveHeader, srcArchiveHeader.sizeof);

    /* Allocate in ar the array of Content
     */
    size_t length = fileNames.length;
    ar.allocate(length * Content.sizeof);

    /* Temporary array of Content
     */
    Content[] contents = (cast(Content*)mem.xmalloc(length * Content.sizeof))[0 .. length];

    /* Write the name strings to ar
     */
    foreach (i, ref content; contents[])
    {
        const(char)* fnp = fileNames[i];
        const(char)[] fn = fnp[nameStart .. strlen(fnp)];       // slice off path/ prefix
        if (log) printf("fn: %.*s\n", cast(int)fn.length, fn.ptr);

        content.nameOffset = cast(uint)ar.length;
        content.nameLength = cast(uint)fn.length;
        //printf("1content.nameOffset[%lld]: %d nameLength: %d\n", i, content.nameOffset, content.nameLength);

        ar.writeStringz(fn);
    }

    /* Read the files, and write their contents to ar, along with
     * a terminating 4 bytes of 0 (to accommodate dchar source files)
     */
    OutBuffer fb;
    foreach (i, ref content; contents[])
    {
        fb.reset();                          // recycle read buffer
        File.read(fileNames[i][0 .. strlen(fileNames[i])], fb); // read file into fb
        content.importOffset = cast(uint)ar.length;
        content.importLength = cast(uint)fb.length; // don't include terminating 0
        ar.write(fb.peekSlice());                   // append file contents to ar
        ar.write32(0);                              // append 4 bytes of 0
    }

    /* Copy contents[] into ar
     */
    Content[] cfcontents = (cast(Content*)(ar.peekSlice().ptr + srcArchiveHeader.contentsOffset))[0 .. length];
    cfcontents[] = contents[];
    mem.xfree(contents.ptr);

    /* Create source archive file name by appending ".sar" to pathPackage
     */
    auto sourceArchiveFileName = FileName.addExt(pathPackage, sar_ext);

    /* write the source archive file
     */
    if (log) printf("writing sourceArchive file %.*s\n", cast(int)sourceArchiveFileName.length, sourceArchiveFileName.ptr);
    if (!writeFile(sourceArchiveFileName.ptr, ar.peekSlice()))
        return true;    // failure

    return false; // success
}

/**********************************************
 * Read the source archive file, making it a memory mapped file.
 * Fill the FileManager.pathCache.pathStatus for each of the paths in the source archive,
 * and the contents of the files in the archive go in FileManager.files.
 * Since it is a memory mapped file, the contents are only read when the module is
 * actually imported.
 * Params:
 *      fileManager = manages files
 *      path = path to location of .sar file
 *      pkg = a package name the path leads to
 *      fnSink = send file names in .sar file to fnSink
 *      eSink = where messages go
 *      verbose = verbose output
 * Returns:
 *      true = success
 *      false = failure
 */
nothrow
bool readSourceArchive(FileManager fileManager, const(char)[] path, const(char)[] pkg, void delegate(const(char)[]) nothrow fnSink,
        ErrorSink eSink, bool verbose)
{
    //printf("reading .sar file path: '%.*s', pkg: '%.*s')\n", cast(int)path.length, path.ptr, cast(int)pkg.length, pkg.ptr);
    enum log = false;
    if (log)
        eSink.message(Loc.initial, "reading .sar file path: '%.*s', pkg: '%.*s')", cast(int)path.length, path.ptr, cast(int)pkg.length, pkg.ptr);

    /* Combine path, pkg, and .sar into path/pkg.sar
     */
    const(char)[] pathPackage = FileName.combine(path, pkg);
    const(char)[] sourceArchiveFileName = FileName.defaultExt(pathPackage, sar_ext);

    /* add the path to the archive file as a disk directory
     */
    fileManager.pathCache.addPath(sourceArchiveFileName, DIR.disk);

    /* Open memory mapped file on sourceArchiveFileName
     */
    static if (1) // memory mapped file
    {
        //fprintf(stderr, "map file '%s'\n", sourceArchiveFileName.ptr);
        auto mmFile = new FileMapping!(const char)(sourceArchiveFileName.ptr);
        auto data = (*mmFile)[];    // all the data in the file
    }
    else // regular file read
    {
        OutBuffer buf;
        if (File.read(sourceArchiveFileName, buf))
        {
            if (log)
                eSink.message(Loc.initial, " .sar file %s not found", sourceArchiveFileName.ptr);
            return false;           // empty files are ok
        }
        auto data = buf.extractSlice(true);    // all the data in the file
    }
    if (data.length == 0)
    {
        if (log)
            eSink.message(Loc.initial, " .sar file is empty");
        return false;           // empty files are ok
    }

    if (verbose)
        eSink.message(Loc.initial, "reading source archive '%.*s%s%.*s.sar' with files:)",
            cast(int)path.length, path.ptr,
            (path.length ? "/".ptr : "".ptr),
            cast(int)pkg.length, pkg.ptr);

    SrcArchiveHeader* srcArchiveHeader = cast(SrcArchiveHeader*)data.ptr;
    if (data.length < SrcArchiveHeader.sizeof ||
        srcArchiveHeader.magicNumber != SrcArchiveHeader.MagicNumber ||
        srcArchiveHeader.versionNumber != 1 ||
        data.length < srcArchiveHeader.contentsOffset ||
        srcArchiveHeader.contentsLength >= uint.max / Content.sizeof - srcArchiveHeader.contentsOffset || // overflow check
        data.length < srcArchiveHeader.contentsOffset + srcArchiveHeader.contentsLength * Content.sizeof)
    {
        eSink.error(Loc.initial, "corrupt .sar file header");
        return false;    // corrupt file
    }

    foreach (i; 0 .. srcArchiveHeader.contentsLength)
    {
        const Content* cp = cast(const(Content)*)(data.ptr + srcArchiveHeader.contentsOffset + i * Content.sizeof);

        if (data.length <= cp.nameOffset ||
            cp.nameOffset >= cp.nameOffset + cp.nameLength + 1 ||
            data.length <= cp.nameOffset + cp.nameLength + 1 ||
            data.length <= cp.importOffset ||
            cp.importOffset >= cp.importOffset + cp.importLength + 1 ||
            data.length <= cp.importOffset + cp.importLength + 1)
        {
            eSink.error(Loc.initial, "corrupt .sar file contents");
            return false;    // corrupt file
        }

        const(char)[] fileName = (data.ptr + cp.nameOffset)[0 .. cp.nameLength];
        const(ubyte)[] fileContents = (cast(const(ubyte)*)(data.ptr + cp.importOffset))[0 .. cp.importLength];

        //fprintf(stderr, "fileContents: %s %p[%d]\n", fileName.ptr, fileContents.ptr, cast(int)fileContents.length);
        //fprintf(stderr, "fileContents: %s\n", fileContents.ptr);

        // Cache file name and file contents (but don't read the file contents!)
        const(char)[] fqn = FileName.combine(path, fileName);
        fileManager.addSarFileNameAndContents(fqn, fileContents);
        if (fnSink)
            fnSink(fqn);
        if (verbose)
            eSink.message(Loc.initial, " %.*s", cast(int)fqn.length, fqn.ptr);
    }
    if (verbose)
        eSink.message(Loc.initial, "done reading source archive");

    return true;
}

/***************************
 * The source archive file starts with this header.
 */
struct SrcArchiveHeader
{
    enum MagicNumber = 0x64FE_ED63;
    uint magicNumber = MagicNumber;     // don't collide with other file types
    uint versionNumber = 1;             // so we can change the format
    uint contentsOffset;                // file offset to start of contents section
    uint contentsLength;                // the number of contents in the contents section
}

/* The contents section is an array of Contents
 */
struct Content
{
    uint nameOffset;    // file offset to name of file
    uint nameLength;    // number of characters in name, excluding terminating 0
    uint importOffset;  // file offset to start of imported file contents
    uint importLength;  // number of characters in the imported file contents, excluding terminating 0
}
