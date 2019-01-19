/**
 * Compiler implementation of the D programming language
 * http://dlang.org
 *
 * Copyright: Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:   Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/root/filename.d, root/_filename.d)
 * Documentation:  https://dlang.org/phobos/dmd_root_filename.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/root/filename.d
 */

module dmd.root.filename;

import core.stdc.ctype;
import core.stdc.errno;
import core.stdc.string;
import dmd.root.array;
import dmd.root.file;
import dmd.root.outbuffer;
import dmd.root.port;
import dmd.root.rmem;
import dmd.root.rootobject;
import dmd.utils;

version (Posix)
{
    import core.sys.posix.stdlib;
    import core.sys.posix.sys.stat;
    import core.sys.posix.unistd : getcwd;
}

version (Windows)
{
    import core.sys.windows.winbase;
    import core.sys.windows.windef;
    import core.sys.windows.winnls;

    extern (Windows) DWORD GetFullPathNameW(LPCWSTR, DWORD, LPWSTR, LPWSTR*) nothrow @nogc;
    extern (Windows) void SetLastError(DWORD) nothrow @nogc;
    extern (C) char* getcwd(char* buffer, size_t maxlen) nothrow;
}

version (CRuntime_Glibc)
{
    extern (C) char* canonicalize_file_name(const char*) nothrow;
}

alias Strings = Array!(const(char)*);
alias Files = Array!(File*);

/***********************************************************
 * Encapsulate path and file names.
 */
struct FileName
{
nothrow:
    private const(char)[] str;

    ///
    extern (D) this(const(char)[] str)
    {
        this.str = str.xarraydup;
    }

    /// Compare two name according to the platform's rules (case sensitive or not)
    extern (C++) static bool equals(const(char)* name1, const(char)* name2) pure
    {
        return equals(name1.toDString, name2.toDString);
    }

    /// Ditto
    extern (D) static bool equals(const(char)[] name1, const(char)[] name2) pure
    {
        if (name1.length != name2.length)
            return false;

        version (Windows)
        {
            return Port.memicmp(name1.ptr, name2.ptr, name1.length) == 0;
        }
        else
        {
            return name1 == name2;
        }
    }

    /************************************
     * Determine if path is absolute.
     * Params:
     *  name = path
     * Returns:
     *  true if absolute path name.
     */
    extern (C++) static bool absolute(const(char)* name) pure
    {
        return absolute(name.toDString);
    }

    /// Ditto
    extern (D) static bool absolute(const(char)[] name) pure
    {
        if (!name.length)
            return false;

        version (Windows)
        {
            return (name[0] == '\\') || (name[0] == '/')
                || (name.length >= 2 && name[1] == ':');
        }
        else version (Posix)
        {
            return (name[0] == '/');
        }
        else
        {
            assert(0);
        }
    }

    unittest
    {
        assert(absolute("/"[]) == true);
        assert(absolute(""[]) == false);
    }

    /**
    Return the given name as an absolute path

    Params:
        name = path
        base = the absolute base to prefix name with if it is relative

    Returns: name as an absolute path relative to base
    */
    extern (C++) static const(char)* toAbsolute(const(char)* name, const(char)* base = null)
    {
        const name_ = name.toDString();
        const base_ = base ? base.toDString() : getcwd(null, 0).toDString();
        return absolute(name_) ? name : combine(base_, name_).ptr;
    }

    /********************************
     * Determine file name extension as slice of input.
     * Params:
     *  str = file name
     * Returns:
     *  filename extension (read-only).
     *  Points past '.' of extension.
     *  If there isn't one, return null.
     */
    extern (C++) static const(char)* ext(const(char)* str) pure
    {
        return ext(str.toDString).ptr;
    }

    /// Ditto
    extern (D) static const(char)[] ext(const(char)[] str) nothrow pure @safe @nogc
    {
        foreach_reverse (idx, char e; str)
        {
            switch (e)
            {
            case '.':
                return str[idx + 1 .. $];
            version (Posix)
            {
            case '/':
                return null;
            }
            version (Windows)
            {
            case '\\':
            case ':':
            case '/':
                return null;
            }
            default:
                continue;
            }
        }
        return null;
    }

    unittest
    {
        assert(ext("/foo/bar/dmd.conf"[]) == "conf");
        assert(ext("object.o"[]) == "o");
        assert(ext("/foo/bar/dmd"[]) == null);
        assert(ext(".objdir.o/object"[]) == null);
        assert(ext([]) == null);
    }

    extern (C++) const(char)* ext() const pure
    {
        return ext(str).ptr;
    }

    /********************************
     * Return file name without extension.
     *
     * TODO:
     * Once slice are used everywhere and `\0` is not assumed,
     * this can be turned into a simple slicing.
     *
     * Params:
     *  str = file name
     *
     * Returns:
     *  mem.xmalloc'd filename with extension removed.
     */
    extern (C++) static const(char)* removeExt(const(char)* str)
    {
        return removeExt(str.toDString).ptr;
    }

    /// Ditto
    extern (D) static const(char)[] removeExt(const(char)[] str)
    {
        auto e = ext(str);
        if (e.length)
        {
            const len = (str.length - e.length) - 1; // -1 for the dot
            char* n = cast(char*)mem.xmalloc(len + 1);
            memcpy(n, str.ptr, len);
            n[len] = 0;
            return n[0 .. len];
        }
        return mem.xstrdup(str.ptr)[0 .. str.length];
    }

    unittest
    {
        assert(removeExt("/foo/bar/object.d"[]) == "/foo/bar/object");
        assert(removeExt("/foo/bar/frontend.di"[]) == "/foo/bar/frontend");
    }

    /********************************
     * Return filename name excluding path (read-only).
     */
    extern (C++) static const(char)* name(const(char)* str) pure
    {
        return name(str.toDString).ptr;
    }

    /// Ditto
    extern (D) static const(char)[] name(const(char)[] str) pure
    {
        foreach_reverse (idx, char e; str)
        {
            switch (e)
            {
                version (Posix)
                {
                case '/':
                    return str[idx + 1 .. $];
                }
                version (Windows)
                {
                case '/':
                case '\\':
                    return str[idx + 1 .. $];
                case ':':
                    /* The ':' is a drive letter only if it is the second
                     * character or the last character,
                     * otherwise it is an ADS (Alternate Data Stream) separator.
                     * Consider ADS separators as part of the file name.
                     */
                    if (idx == 1 || idx == str.length - 1)
                        return str[idx + 1 .. $];
                    break;
                }
            default:
                break;
            }
        }
        return str;
    }

    extern (C++) const(char)* name() const pure
    {
        return name(str).ptr;
    }

    unittest
    {
        assert(name("/foo/bar/object.d"[]) == "object.d");
        assert(name("/foo/bar/frontend.di"[]) == "frontend.di");
    }

    /**************************************
     * Return path portion of str.
     * Path will does not include trailing path separator.
     */
    extern (C++) static const(char)* path(const(char)* str)
    {
        return path(str.toDString).ptr;
    }

    /// Ditto
    extern (D) static const(char)[] path(const(char)[] str)
    {
        const n = name(str);
        bool hasTrailingSlash;
        if (n.length < str.length)
        {
            version (Posix)
            {
                if (str[$ - n.length - 1] == '/')
                    hasTrailingSlash = true;
            }
            else version (Windows)
            {
                if (str[$ - n.length - 1] == '\\' || str[$ - n.length - 1] == '/')
                    hasTrailingSlash = true;
            }
            else
            {
                assert(0);
            }
        }
        const pathlen = str.length - n.length - (hasTrailingSlash ? 1 : 0);
        char* path = cast(char*)mem.xmalloc(pathlen + 1);
        memcpy(path, str.ptr, pathlen);
        path[pathlen] = 0;
        return path[0 .. pathlen];
    }

    unittest
    {
        assert(path("/foo/bar"[]) == "/foo");
        assert(path("foo"[]) == "");
    }

    /**************************************
     * Replace filename portion of path.
     */
    extern (D) static const(char)[] replaceName(const(char)[] path, const(char)[] name)
    {
        if (absolute(name))
            return name;
        auto n = FileName.name(path);
        if (n == path)
            return name;
        return combine(path[0 .. $ - n.length], name);
    }

    /**
       Combine a `path` and a file `name`

       Params:
         path = Path to append to
         name = Name to append to path

       Returns:
         The `\0` terminated string which is the combination of `path` and `name`
         and a valid path.
    */
    extern (C++) static const(char)* combine(const(char)* path, const(char)* name)
    {
        if (!path)
            return name;
        return combine(path.toDString, name.toDString).ptr;
    }

    /// Ditto
    extern(D) static const(char)[] combine(const(char)[] path, const(char)[] name)
    {
        if (!path.length)
            return name;

        char* f = cast(char*)mem.xmalloc(path.length + 1 + name.length + 1);
        memcpy(f, path.ptr, path.length);
        bool trailingSlash = false;
        version (Posix)
        {
            if (path[$ - 1] != '/')
            {
                f[path.length] = '/';
                trailingSlash = true;
            }
        }
        else version (Windows)
        {
            if (path[$ - 1] != '\\' && path[$ - 1] != '/' && path[$ - 1] != ':')
            {
                f[path.length] = '\\';
                trailingSlash = true;
            }
        }
        else
        {
            assert(0);
        }
        const len = path.length + trailingSlash;
        memcpy(f + len, name.ptr, name.length);
        // Note: At the moment `const(char)*` are being transitioned to
        // `const(char)[]`. To avoid bugs crippling in, we `\0` terminate
        // slices, but don't include it in the slice so `.ptr` can be used.
        f[len + name.length] = '\0';
        return f[0 .. len + name.length];
    }

    unittest
    {
        version (Windows)
            assert(combine("foo"[], "bar"[]) == "foo\\bar");
        else
            assert(combine("foo"[], "bar"[]) == "foo/bar");
        assert(combine("foo/"[], "bar"[]) == "foo/bar");
    }

    static const(char)* buildPath(const(char)* path, const(char)*[] names...)
    {
        foreach (const(char)* name; names)
            path = combine(path, name);
        return path;
    }

    // Split a path into an Array of paths
    extern (C++) static Strings* splitPath(const(char)* path)
    {
        char c = 0; // unnecessary initializer is for VC /W4
        const(char)* p;
        OutBuffer buf;
        Strings* array;
        array = new Strings();
        if (path)
        {
            p = path;
            do
            {
                char instring = 0;
                while (isspace(cast(char)*p)) // skip leading whitespace
                    p++;
                buf.reserve(strlen(p) + 1); // guess size of path
                for (;; p++)
                {
                    c = *p;
                    switch (c)
                    {
                    case '"':
                        instring ^= 1; // toggle inside/outside of string
                        continue;
                        version (OSX)
                        {
                        case ',':
                        }
                        version (Windows)
                        {
                        case ';':
                        }
                        version (Posix)
                        {
                        case ':':
                        }
                        p++;
                        break;
                        // note that ; cannot appear as part
                        // of a path, quotes won't protect it
                    case 0x1A:
                        // ^Z means end of file
                    case 0:
                        break;
                    case '\r':
                        continue;
                        // ignore carriage returns
                        version (Posix)
                        {
                        case '~':
                            {
                                char* home = getenv("HOME");
                                if (home)
                                    buf.writestring(home);
                                else
                                    buf.writestring("~");
                                continue;
                            }
                        }
                        version (none)
                        {
                        case ' ':
                        case '\t':
                            // tabs in filenames?
                            if (!instring) // if not in string
                                break;
                            // treat as end of path
                        }
                    default:
                        buf.writeByte(c);
                        continue;
                    }
                    break;
                }
                if (buf.offset) // if path is not empty
                {
                    array.push(buf.extractString());
                }
            }
            while (c);
        }
        return array;
    }

    /**
     * Add the extension `ext` to `name`, regardless of the content of `name`
     *
     * Params:
     *   name = Path to append the extension to
     *   ext  = Extension to add (should not include '.')
     *
     * Returns:
     *   A newly allocated string (free with `FileName.free`)
     */
    extern(D) static char[] addExt(const(char)[] name, const(char)[] ext)
    {
        const len = name.length + ext.length + 2;
        auto s = cast(char*)mem.xmalloc(len);
        s[0 .. name.length] = name[];
        s[name.length] = '.';
        s[name.length + 1 .. len - 1] = ext[];
        s[len - 1] = '\0';
        return s[0 .. len - 1];
    }


    /***************************
     * Free returned value with FileName::free()
     */
    extern (C++) static const(char)* defaultExt(const(char)* name, const(char)* ext)
    {
        return defaultExt(name.toDString, ext.toDString).ptr;
    }

    /// Ditto
    extern (D) static const(char)[] defaultExt(const(char)[] name, const(char)[] ext)
    {
        auto e = FileName.ext(name);
        if (e.length) // it already has an extension
            return name.xarraydup;
        return addExt(name, ext);
    }

    unittest
    {
        assert(defaultExt("/foo/object.d"[], "d") == "/foo/object.d");
        assert(defaultExt("/foo/object"[], "d") == "/foo/object.d");
        assert(defaultExt("/foo/bar.d"[], "o") == "/foo/bar.d");
    }

    /***************************
     * Free returned value with FileName::free()
     */
    extern (C++) static const(char)* forceExt(const(char)* name, const(char)* ext)
    {
        return forceExt(name.toDString, ext.toDString).ptr;
    }

    /// Ditto
    extern (D) static const(char)[] forceExt(const(char)[] name, const(char)[] ext)
    {
        if (auto e = FileName.ext(name))
            return addExt(name[0 .. $ - e.length - 1], ext);
        return defaultExt(name, ext); // doesn't have one
    }

    unittest
    {
        assert(forceExt("/foo/object.d"[], "d") == "/foo/object.d");
        assert(forceExt("/foo/object"[], "d") == "/foo/object.d");
        assert(forceExt("/foo/bar.d"[], "o") == "/foo/bar.o");
    }

    /// Returns:
    ///   `true` if `name`'s extension is `ext`
    extern (C++) static bool equalsExt(const(char)* name, const(char)* ext) pure
    {
        return equalsExt(name.toDString, ext.toDString);
    }

    /// Ditto
    extern (D) static bool equalsExt(const(char)[] name, const(char)[] ext) pure
    {
        auto e = FileName.ext(name);
        if (!e.length && !ext.length)
            return true;
        if (!e.length || !ext.length)
            return false;
        return FileName.equals(e, ext);
    }

    unittest
    {
        assert(!equalsExt("foo.bar"[], "d"));
        assert(equalsExt("foo.bar"[], "bar"));
        assert(equalsExt("object.d"[], "d"));
        assert(!equalsExt("object"[], "d"));
    }

    /******************************
     * Return !=0 if extensions match.
     */
    extern (C++) bool equalsExt(const(char)* ext) const pure
    {
        return equalsExt(str, ext.toDString());
    }

    /*************************************
     * Search Path for file.
     * Input:
     *      cwd     if true, search current directory before searching path
     */
    extern (C++) static const(char)* searchPath(Strings* path, const(char)* name, bool cwd)
    {
        return searchPath(path, name.toDString, cwd).ptr;
    }

    extern (D) static const(char)[] searchPath(Strings* path, const(char)[] name, bool cwd)
    {
        if (absolute(name))
        {
            return exists(name) ? name : null;
        }
        if (cwd)
        {
            if (exists(name))
                return name;
        }
        if (path)
        {
            foreach (p; *path)
            {
                auto n = combine(p.toDString, name);
                if (exists(n))
                    return n;
            }
        }
        return null;
    }

    /*************************************
     * Search Path for file in a safe manner.
     *
     * Be wary of CWE-22: Improper Limitation of a Pathname to a Restricted Directory
     * ('Path Traversal') attacks.
     *      http://cwe.mitre.org/data/definitions/22.html
     * More info:
     *      https://www.securecoding.cert.org/confluence/display/c/FIO02-C.+Canonicalize+path+names+originating+from+tainted+sources
     * Returns:
     *      NULL    file not found
     *      !=NULL  mem.xmalloc'd file name
     */
    extern (C++) static const(char)* safeSearchPath(Strings* path, const(char)* name)
    {
        version (Windows)
        {
            // don't allow leading / because it might be an absolute
            // path or UNC path or something we'd prefer to just not deal with
            if (*name == '/')
            {
                return null;
            }
            /* Disallow % \ : and .. in name characters
             * We allow / for compatibility with subdirectories which is allowed
             * on dmd/posix. With the leading / blocked above and the rest of these
             * conservative restrictions, we should be OK.
             */
            for (const(char)* p = name; *p; p++)
            {
                char c = *p;
                if (c == '\\' || c == ':' || c == '%' || (c == '.' && p[1] == '.') || (c == '/' && p[1] == '/'))
                {
                    return null;
                }
            }
            return FileName.searchPath(path, name, false);
        }
        else version (Posix)
        {
            /* Even with realpath(), we must check for // and disallow it
             */
            for (const(char)* p = name; *p; p++)
            {
                char c = *p;
                if (c == '/' && p[1] == '/')
                {
                    return null;
                }
            }
            if (path)
            {
                /* Each path is converted to a cannonical name and then a check is done to see
                 * that the searched name is really a child one of the the paths searched.
                 */
                for (size_t i = 0; i < path.dim; i++)
                {
                    const(char)* cname = null;
                    const(char)* cpath = canonicalName((*path)[i]);
                    //printf("FileName::safeSearchPath(): name=%s; path=%s; cpath=%s\n",
                    //      name, (char *)path.data[i], cpath);
                    if (cpath is null)
                        goto cont;
                    cname = canonicalName(combine(cpath, name));
                    //printf("FileName::safeSearchPath(): cname=%s\n", cname);
                    if (cname is null)
                        goto cont;
                    //printf("FileName::safeSearchPath(): exists=%i "
                    //      "strncmp(cpath, cname, %i)=%i\n", exists(cname),
                    //      strlen(cpath), strncmp(cpath, cname, strlen(cpath)));
                    // exists and name is *really* a "child" of path
                    if (exists(cname) && strncmp(cpath, cname, strlen(cpath)) == 0)
                    {
                        .free(cast(void*)cpath);
                        const(char)* p = mem.xstrdup(cname);
                        .free(cast(void*)cname);
                        return p;
                    }
                cont:
                    if (cpath)
                        .free(cast(void*)cpath);
                    if (cname)
                        .free(cast(void*)cname);
                }
            }
            return null;
        }
        else
        {
            assert(0);
        }
    }

    /**
       Check if the file the `path` points to exists

       Returns:
         0 if it does not exists
         1 if it exists and is not a directory
         2 if it exists and is a directory
     */
    extern (C++) static int exists(const(char)* name)
    {
        return exists(name.toDString);
    }

    /// Ditto
    extern (D) static int exists(const(char)[] name)
    {
        if (!name.length)
            return 0;
        version (Posix)
        {
            stat_t st;
            if (name.toCStringThen!((v) => stat(v.ptr, &st)) < 0)
                return 0;
            if (S_ISDIR(st.st_mode))
                return 2;
            return 1;
        }
        else version (Windows)
        {
            return name.toCStringThen!((cstr) => cstr.toWStringzThen!((wname)
            {
                const dw = GetFileAttributesW(&wname[0]);
                if (dw == -1)
                    return 0;
                else if (dw & FILE_ATTRIBUTE_DIRECTORY)
                    return 2;
                else
                    return 1;
            }));
        }
        else
        {
            assert(0);
        }
    }

    /**
       Ensure that the provided path exists

       Accepts a path to either a file or a directory.
       In the former case, the basepath (path to the containing directory)
       will be checked for existence, and created if it does not exists.
       In the later case, the directory pointed to will be checked for existence
       and created if needed.

       Params:
         path = a path to a file or a directory

       Returns:
         `true` if the directory exists or was successfully created
     */
    extern (C++) static bool ensurePathExists(const(char)* path)
    {
        //printf("FileName::ensurePathExists(%s)\n", path ? path : "");
        if (!path || !(*path))
            return true;
        if (exists(path))
            return true;

        // We were provided with a file name
        // We need to call ourselves recursively to ensure parent dir exist
        const(char)* p = FileName.path(path);
        if (*p)
        {
            version (Windows)
            {
                const len = strlen(path);
                const plen = strlen(p);
                // Note: Windows filename comparison should be case-insensitive,
                // however p is a subslice of path so we don't need it
                if (len == plen ||
                    (len > 2 && path[1] == ':' && path[2 .. len] == p[0 .. plen]))
                {
                    mem.xfree(cast(void*)p);
                    return true;
                }
            }
            const r = ensurePathExists(p);
            mem.xfree(cast(void*)p);

            if (!r)
                return r;
        }

        version (Windows)
            const r = _mkdir(path.toDString);
        version (Posix)
        {
            errno = 0;
            const r = mkdir(path, (7 << 6) | (7 << 3) | 7);
        }

        if (r == 0)
            return true;

        // Don't error out if another instance of dmd just created
        // this directory
        version (Windows)
        {
            import core.sys.windows.winerror : ERROR_ALREADY_EXISTS;
            if (GetLastError() == ERROR_ALREADY_EXISTS)
                return true;
        }
        version (Posix)
        {
            if (errno == EEXIST)
                return true;
        }

        return false;
    }

    /******************************************
     * Return canonical version of name in a malloc'd buffer.
     * This code is high risk.
     */
    extern (C++) static const(char)* canonicalName(const(char)* name)
    {
        return canonicalName(name.toDString).ptr;
    }

    /// Ditto
    extern (D) static const(char)[] canonicalName(const(char)[] name)
    {
        version (Posix)
        {
            import core.stdc.limits;      // PATH_MAX
            import core.sys.posix.unistd; // _PC_PATH_MAX

            // Have realpath(), passing a NULL destination pointer may return an
            // internally malloc'd buffer, however it is implementation defined
            // as to what happens, so cannot rely on it.
            static if (__traits(compiles, PATH_MAX))
            {
                // Have compile time limit on filesystem path, use it with realpath.
                char[PATH_MAX] buf = void;
                auto path = name.toCStringThen!((n) => realpath(n.ptr, buf.ptr));
                if (path !is null)
                    return mem.xstrdup(path).toDString;
            }
            else static if (__traits(compiles, canonicalize_file_name))
            {
                // Have canonicalize_file_name, which malloc's memory.
                auto path = name.toCStringThen!((n) => canonicalize_file_name(n.ptr));
                if (path !is null)
                    return path.toDString;
            }
            else static if (__traits(compiles, _PC_PATH_MAX))
            {
                // Panic! Query the OS for the buffer limit.
                auto path_max = pathconf("/", _PC_PATH_MAX);
                if (path_max > 0)
                {
                    char *buf = cast(char*)mem.xmalloc(path_max);
                    scope(exit) mem.xfree(buf);
                    auto path = name.toCStringThen!((n) => realpath(n.ptr, buf));
                    if (path !is null)
                        return mem.xstrdup(path).toDString;
                }
            }
            // Give up trying to support this platform, just duplicate the filename
            // unless there is nothing to copy from.
            if (!name.length)
                return null;
            return mem.xstrdup(name.ptr)[0 .. name.length];
        }
        else version (Windows)
        {
            // Convert to wstring first since otherwise the Win32 APIs have a character limit
            return name.toWStringzThen!((wname)
            {
                /* Apparently, there is no good way to do this on Windows.
                 * GetFullPathName isn't it, but use it anyway.
                 */
                // First find out how long the buffer has to be.
                auto fullPathLength = GetFullPathNameW(&wname[0], 0, null, null);
                if (!fullPathLength) return null;
                auto fullPath = new wchar[fullPathLength];

                // Actually get the full path name
                const fullPathLengthNoTerminator = GetFullPathNameW(
                    &wname[0], cast(uint)fullPath.length, &fullPath[0], null /*filePart*/);
                // Unfortunately, when the buffer is large enough the return value is the number of characters
                // _not_ counting the null terminator, so fullPathLengthNoTerminator should be smaller
                assert(fullPathLength > fullPathLengthNoTerminator);

                // Find out size of the converted string
                const retLength = WideCharToMultiByte(
                    0 /*codepage*/, 0 /*flags*/, &fullPath[0], fullPathLength, null, 0, null, null);
                auto ret = new char[retLength];

                // Actually convert to char
                const retLength2 = WideCharToMultiByte(
                    0 /*codepage*/, 0 /*flags*/, &fullPath[0], cast(int)fullPath.length, &ret[0], cast(int)ret.length, null, null);
                assert(retLength == retLength2);

                return ret;
            });
        }
        else
        {
            assert(0);
        }
    }

    /********************************
     * Free memory allocated by FileName routines
     */
    extern (C++) static void free(const(char)* str)
    {
        if (str)
        {
            assert(str[0] != cast(char)0xAB);
            memset(cast(void*)str, 0xAB, strlen(str) + 1); // stomp
        }
        mem.xfree(cast(void*)str);
    }

    extern (C++) const(char)* toChars() const pure nothrow @trusted
    {
        // Since we can return an empty slice (but '\0' terminated),
        // we don't do bounds check (as `&str[0]` does)
        return str.ptr;
    }

    const(char)[] toString() const pure nothrow @trusted
    {
        return str;
    }
}

version(Windows)
{
    /****************************************************************
     * The code before used the POSIX function `mkdir` on Windows. That
     * function is now deprecated and fails with long paths, so instead
     * we use the newer `CreateDirectoryW`.
     *
     * `CreateDirectoryW` is the unicode version of the generic macro
     * `CreateDirectory`.  `CreateDirectoryA` has a file path
     *  limitation of 248 characters, `mkdir` fails with less and might
     *  fail due to the number of consecutive `..`s in the
     *  path. `CreateDirectoryW` also normally has a 248 character
     * limit, unless the path is absolute and starts with `\\?\`. Note
     * that this is different from starting with the almost identical
     * `\\?`.
     *
     * Params:
     *  path = The path to create.
     *
     * Returns:
     *  0 on success, 1 on failure.
     *
     * References:
     *  https://msdn.microsoft.com/en-us/library/windows/desktop/aa363855(v=vs.85).aspx
     */
    private int _mkdir(const(char)[] path) nothrow
    {
        const createRet = path.extendedPathThen!(
            p => CreateDirectoryW(&p[0], null /*securityAttributes*/));
        // different conventions for CreateDirectory and mkdir
        return createRet == 0 ? 1 : 0;
    }

    /**************************************
     * Converts a path to one suitable to be passed to Win32 API
     * functions that can deal with paths longer than 248
     * characters then calls the supplied function on it.
     *
     * Params:
     *  path = The Path to call F on.
     *
     * Returns:
     *  The result of calling F on path.
     *
     * References:
     *  https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247(v=vs.85).aspx
     */
    package auto extendedPathThen(alias F)(const(char)[] path)
    {
        if (!path.length)
            return F((wchar[]).init);
        return path.toWStringzThen!((wpath)
        {
            // GetFullPathNameW expects a sized buffer to store the result in. Since we don't
            // know how large it has to be, we pass in null and get the needed buffer length
            // as the return code.
            const pathLength = GetFullPathNameW(&wpath[0],
                                                0 /*length8*/,
                                                null /*output buffer*/,
                                                null /*filePartBuffer*/);
            if (pathLength == 0)
            {
                return F((wchar[]).init);
            }

            // wpath is the UTF16 version of path, but to be able to use
            // extended paths, we need to prefix with `\\?\` and the absolute
            // path.
            static immutable prefix = `\\?\`w;

            // prefix only needed for long names and non-UNC names
            const needsPrefix = pathLength >= MAX_PATH && (wpath[0] != '\\' || wpath[1] != '\\');
            const prefixLength = needsPrefix ? prefix.length : 0;

            // +1 for the null terminator
            const bufferLength = pathLength + prefixLength + 1;

            wchar[1024] absBuf = void;
            wchar[] absPath = bufferLength > absBuf.length
                ? new wchar[bufferLength] : absBuf[0 .. bufferLength];

            absPath[0 .. prefixLength] = prefix[0 .. prefixLength];

            const absPathRet = GetFullPathNameW(&wpath[0],
                cast(uint)(absPath.length - prefixLength - 1),
                &absPath[prefixLength],
                null /*filePartBuffer*/);

            if (absPathRet == 0 || absPathRet > absPath.length - prefixLength)
            {
                return F((wchar[]).init);
            }

            absPath[$ - 1] = '\0';
            // Strip null terminator from the slice
            return F(absPath[0 .. $ - 1]);
        });
    }

    /**********************************
     * Converts a slice of UTF-8 characters to an array of wchar that's null
     * terminated so it can be passed to Win32 APIs then calls the supplied
     * function on it.
     *
     * Params:
     *  str = The string to convert.
     *
     * Returns:
     *  The result of calling F on the UTF16 version of str.
     */
    private auto toWStringzThen(alias F)(const(char)[] str) nothrow
    {
        if (!str.length) return F(""w.ptr);

        import core.stdc.string: strlen;
        import core.stdc.stdlib: malloc, free;
        import core.sys.windows.winnls: MultiByteToWideChar;
        wchar[1024] buf;
        // first find out how long the buffer must be to store the result

        const length = MultiByteToWideChar(0 /*codepage*/, 0 /*flags*/, &str[0], cast(int)str.length, null, 0);
        if (!length) return F(""w);

        wchar[] ret = length >= buf.length
            ? (cast(wchar*)malloc(length * wchar.sizeof))[0 .. length + 1]
            : buf[0 .. length + 1];
        scope (exit)
        {
            if (&ret[0] != &buf[0])
                free(&ret[0]);
        }
        // actually do the conversion
        const length2 = MultiByteToWideChar(
            0 /*codepage*/, 0 /*flags*/, &str[0], cast(int)str.length, &ret[0], cast(int)length);
        assert(str.length == length2); // should always be true according to the API
        // Add terminating `\0`
        ret[$ - 1] = '\0';

        return F(ret[0 .. $ - 1]);
    }
}

version (Posix)
{
    /**
    Takes a callable F and applies it to the result of converting
    `fileName` to an absolute file path (char*)

    Params:
        fileName = The file name to be converted to an absolute path
    Returns: Whatever `F` returns.
    */
    auto absPathThen(alias F)(const(char)[] fileName)
    {
        auto absPath = FileName.canonicalName(fileName);
        scope(exit) mem.xfree(cast(void*)absPath.ptr);
        return F(cast(char[])absPath);
    }
}
else
{
    /**
    Takes a callable F and applies it to the result of converting
    `fileName` to an absolute file path (char*)

    Params:
        fileName = The file name to be converted to an absolute path
    Returns: Whatever `F` returns.
     */
    auto absPathThen(alias F)(const(char)[] fileName)
    {
        import core.sys.windows.winnls: WideCharToMultiByte;
        import core.stdc.stdlib: malloc, free;

        return fileName.extendedPathThen!((wpath) {
                // first find out how long the buffer must be to store the result
                const length = WideCharToMultiByte(0,    // code page
                                                   0,    // flags
                                                   &wpath[0],
                                                   -1,   // wpath len, -1 is null terminated
                                                   null, // multibyte output ptr
                                                   0,    // multibyte output length
                                                   null, // default char
                                                   null, // if used default char
                );

                if (!length) return F((char[]).init);

                char[1024] buf = void;

                scope multibyteBuf = length > buf.length
                    ? (cast(char*)malloc(length * char.sizeof))[0 .. length]
                    : buf[0 .. length];
                scope (exit)
                {
                    if (multibyteBuf.ptr != buf.ptr)
                        free(multibyteBuf.ptr);
                }

                // now store the result
                const length2 = WideCharToMultiByte(0,    // code page
                                                    0,    // flags
                                                    &wpath[0],
                                                    -1,   // wpath len, -1 is null terminated
                                                    multibyteBuf.ptr,
                                                    length,
                                                    null, // default char
                                                    null, // if used default char
                );

                assert(length == length2);

                return F(multibyteBuf[0 .. length - 1]);
        });
    }
}
