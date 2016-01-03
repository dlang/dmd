// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.root.filename;

import core.stdc.ctype, core.stdc.errno, core.stdc.stdlib, core.stdc.string, core.sys.posix.stdlib, core.sys.posix.sys.stat, core.sys.windows.windows;
import ddmd.root.array, ddmd.root.file, ddmd.root.outbuffer, ddmd.root.rmem, ddmd.root.rootobject;

version (Windows) extern (C) int mkdir(const char*);
version (Windows) alias _mkdir = mkdir;
version (Posix) extern (C) char* canonicalize_file_name(const char*);
version (Windows) extern (C) int stricmp(const char*, const char*);
version (Windows) extern (Windows) DWORD GetFullPathNameA(LPCTSTR lpFileName, DWORD nBufferLength, LPTSTR lpBuffer, LPTSTR* lpFilePart);

alias Strings = Array!(const(char)*);
alias Files = Array!(File*);

/***********************************************************
 */
struct FileName
{
    const(char)* str;

    extern (D) this(const(char)* str)
    {
        this.str = mem.xstrdup(str);
    }

    extern (C++) bool equals(RootObject obj)
    {
        return compare(obj) == 0;
    }

    extern (C++) static bool equals(const(char)* name1, const(char)* name2)
    {
        return compare(name1, name2) == 0;
    }

    extern (C++) int compare(RootObject obj)
    {
        return compare(str, (cast(FileName*)obj).str);
    }

    extern (C++) static int compare(const(char)* name1, const(char)* name2)
    {
        version (Windows)
        {
            return stricmp(name1, name2);
        }
        else
        {
            return strcmp(name1, name2);
        }
    }

    /************************************
     * Return !=0 if absolute path name.
     */
    extern (C++) static bool absolute(const(char)* name)
    {
        version (Windows)
        {
            return (*name == '\\') || (*name == '/') || (*name && name[1] == ':');
        }
        else version (Posix)
        {
            return (*name == '/');
        }
        else
        {
            assert(0);
        }
    }

    /********************************
     * Return filename extension (read-only).
     * Points past '.' of extension.
     * If there isn't one, return NULL.
     */
    extern (C++) static const(char)* ext(const(char)* str)
    {
        size_t len = strlen(str);
        const(char)* e = str + len;
        for (;;)
        {
            switch (*e)
            {
            case '.':
                return e + 1;
                version (Posix)
                {
                case '/':
                    break;
                }
                version (Windows)
                {
                case '\\':
                case ':':
                case '/':
                    break;
                }
            default:
                if (e == str)
                    break;
                e--;
                continue;
            }
            return null;
        }
    }

    extern (C++) const(char)* ext()
    {
        return ext(str);
    }

    /********************************
     * Return mem.xmalloc'd filename with extension removed.
     */
    extern (C++) static const(char)* removeExt(const(char)* str)
    {
        const(char)* e = ext(str);
        if (e)
        {
            size_t len = (e - str) - 1;
            char* n = cast(char*)mem.xmalloc(len + 1);
            memcpy(n, str, len);
            n[len] = 0;
            return n;
        }
        return mem.xstrdup(str);
    }

    /********************************
     * Return filename name excluding path (read-only).
     */
    extern (C++) static const(char)* name(const(char)* str)
    {
        size_t len = strlen(str);
        const(char)* e = str + len;
        for (;;)
        {
            switch (*e)
            {
                version (Posix)
                {
                case '/':
                    return e + 1;
                }
                version (Windows)
                {
                case '/':
                case '\\':
                    return e + 1;
                case ':':
                    /* The ':' is a drive letter only if it is the second
                     * character or the last character,
                     * otherwise it is an ADS (Alternate Data Stream) separator.
                     * Consider ADS separators as part of the file name.
                     */
                    if (e == str + 1 || e == str + len - 1)
                        return e + 1;
                }
            default:
                if (e == str)
                    break;
                e--;
                continue;
            }
            return e;
        }
    }

    extern (C++) const(char)* name()
    {
        return name(str);
    }

    /**************************************
     * Return path portion of str.
     * Path will does not include trailing path separator.
     */
    extern (C++) static const(char)* path(const(char)* str)
    {
        const(char)* n = name(str);
        size_t pathlen;
        if (n > str)
        {
            version (Posix)
            {
                if (n[-1] == '/')
                    n--;
            }
            else version (Windows)
            {
                if (n[-1] == '\\' || n[-1] == '/')
                    n--;
            }
            else
            {
                assert(0);
            }
        }
        pathlen = n - str;
        char* path = cast(char*)mem.xmalloc(pathlen + 1);
        memcpy(path, str, pathlen);
        path[pathlen] = 0;
        return path;
    }

    /**************************************
     * Replace filename portion of path.
     */
    extern (C++) static const(char)* replaceName(const(char)* path, const(char)* name)
    {
        size_t pathlen;
        size_t namelen;
        if (absolute(name))
            return name;
        const(char)* n = FileName.name(path);
        if (n == path)
            return name;
        pathlen = n - path;
        namelen = strlen(name);
        char* f = cast(char*)mem.xmalloc(pathlen + 1 + namelen + 1);
        memcpy(f, path, pathlen);
        version (Posix)
        {
            if (path[pathlen - 1] != '/')
            {
                f[pathlen] = '/';
                pathlen++;
            }
        }
        else version (Windows)
        {
            if (path[pathlen - 1] != '\\' && path[pathlen - 1] != '/' && path[pathlen - 1] != ':')
            {
                f[pathlen] = '\\';
                pathlen++;
            }
        }
        else
        {
            assert(0);
        }
        memcpy(f + pathlen, name, namelen + 1);
        return f;
    }

    extern (C++) static const(char)* combine(const(char)* path, const(char)* name)
    {
        char* f;
        size_t pathlen;
        size_t namelen;
        if (!path || !*path)
            return cast(char*)name;
        pathlen = strlen(path);
        namelen = strlen(name);
        f = cast(char*)mem.xmalloc(pathlen + 1 + namelen + 1);
        memcpy(f, path, pathlen);
        version (Posix)
        {
            if (path[pathlen - 1] != '/')
            {
                f[pathlen] = '/';
                pathlen++;
            }
        }
        else version (Windows)
        {
            if (path[pathlen - 1] != '\\' && path[pathlen - 1] != '/' && path[pathlen - 1] != ':')
            {
                f[pathlen] = '\\';
                pathlen++;
            }
        }
        else
        {
            assert(0);
        }
        memcpy(f + pathlen, name, namelen + 1);
        return f;
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

    /***************************
     * Free returned value with FileName::free()
     */
    extern (C++) static const(char)* defaultExt(const(char)* name, const(char)* ext)
    {
        const(char)* e = FileName.ext(name);
        if (e) // if already has an extension
            return mem.xstrdup(name);
        size_t len = strlen(name);
        size_t extlen = strlen(ext);
        char* s = cast(char*)mem.xmalloc(len + 1 + extlen + 1);
        memcpy(s, name, len);
        s[len] = '.';
        memcpy(s + len + 1, ext, extlen + 1);
        return s;
    }

    /***************************
     * Free returned value with FileName::free()
     */
    extern (C++) static const(char)* forceExt(const(char)* name, const(char)* ext)
    {
        const(char)* e = FileName.ext(name);
        if (e) // if already has an extension
        {
            size_t len = e - name;
            size_t extlen = strlen(ext);
            char* s = cast(char*)mem.xmalloc(len + extlen + 1);
            memcpy(s, name, len);
            memcpy(s + len, ext, extlen + 1);
            return s;
        }
        else
            return defaultExt(name, ext); // doesn't have one
    }

    extern (C++) static bool equalsExt(const(char)* name, const(char)* ext)
    {
        const(char)* e = FileName.ext(name);
        if (!e && !ext)
            return true;
        if (!e || !ext)
            return false;
        return FileName.compare(e, ext) == 0;
    }

    /******************************
     * Return !=0 if extensions match.
     */
    extern (C++) bool equalsExt(const(char)* ext)
    {
        return equalsExt(str, ext);
    }

    /*************************************
     * Search Path for file.
     * Input:
     *      cwd     if true, search current directory before searching path
     */
    extern (C++) static const(char)* searchPath(Strings* path, const(char)* name, bool cwd)
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
            for (size_t i = 0; i < path.dim; i++)
            {
                const(char)* p = (*path)[i];
                const(char)* n = combine(p, name);
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
     *      https://www.securecoding.cert.org/confluence/display/seccode/FIO02-C.+Canonicalize+path+names+originating+from+untrusted+sources
     * Returns:
     *      NULL    file not found
     *      !=NULL  mem.xmalloc'd file name
     */
    extern (C++) static const(char)* safeSearchPath(Strings* path, const(char)* name)
    {
        version (Windows)
        {
            /* Disallow % / \ : and .. in name characters
             */
            for (const(char)* p = name; *p; p++)
            {
                char c = *p;
                if (c == '\\' || c == '/' || c == ':' || c == '%' || (c == '.' && p[1] == '.'))
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
                    //      name, (char *)path->data[i], cpath);
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

    extern (C++) static int exists(const(char)* name)
    {
        version (Posix)
        {
            stat_t st;
            if (stat(name, &st) < 0)
                return 0;
            if (S_ISDIR(st.st_mode))
                return 2;
            return 1;
        }
        else version (Windows)
        {
            DWORD dw;
            int result;
            dw = GetFileAttributesA(name);
            if (dw == -1)
                result = 0;
            else if (dw & FILE_ATTRIBUTE_DIRECTORY)
                result = 2;
            else
                result = 1;
            return result;
        }
        else
        {
            assert(0);
        }
    }

    extern (C++) static bool ensurePathExists(const(char)* path)
    {
        //printf("FileName::ensurePathExists(%s)\n", path ? path : "");
        if (path && *path)
        {
            if (!exists(path))
            {
                const(char)* p = FileName.path(path);
                if (*p)
                {
                    version (Windows)
                    {
                        size_t len = strlen(path);
                        if ((len > 2 && p[-1] == ':' && strcmp(path + 2, p) == 0) || len == strlen(p))
                        {
                            mem.xfree(cast(void*)p);
                            return 0;
                        }
                    }
                    bool r = ensurePathExists(p);
                    mem.xfree(cast(void*)p);
                    if (r)
                        return r;
                }
                version (Windows)
                {
                    char sep = '\\';
                }
                else version (Posix)
                {
                    char sep = '/';
                }
                if (path[strlen(path) - 1] != sep)
                {
                    //printf("mkdir(%s)\n", path);
                    version (Windows)
                    {
                        int r = _mkdir(path);
                    }
                    version (Posix)
                    {
                        int r = mkdir(path, (7 << 6) | (7 << 3) | 7);
                    }
                    if (r)
                    {
                        /* Don't error out if another instance of dmd just created
                         * this directory
                         */
                        if (errno != EEXIST)
                            return true;
                    }
                }
            }
        }
        return false;
    }

    /******************************************
     * Return canonical version of name in a malloc'd buffer.
     * This code is high risk.
     */
    extern (C++) static const(char)* canonicalName(const(char)* name)
    {
        version (Posix)
        {
            // NULL destination buffer is allowed and preferred
            return realpath(name, null);
        }
        else version (Windows)
        {
            /* Apparently, there is no good way to do this on Windows.
             * GetFullPathName isn't it, but use it anyway.
             */
            DWORD result = GetFullPathNameA(name, 0, null, null);
            if (result)
            {
                char* buf = cast(char*)malloc(result);
                result = GetFullPathNameA(name, result, buf, null);
                if (result == 0)
                {
                    .free(buf);
                    return null;
                }
                return buf;
            }
            return null;
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

    extern (C++) char* toChars()
    {
        return cast(char*)str; // toChars() should really be const
    }
}
