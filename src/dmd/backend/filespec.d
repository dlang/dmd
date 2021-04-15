/*_ filespec.h   Fri Jul  8 1988   Modified by: bright */
/* Copyright (C) 1986-1987 by Northwest Software        */
/* All Rights Reserved                                  */
/* Written by Walter Bright                             */
module dmd.backend.filespec;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.mem;

extern (C++):

nothrow:
@safe:

/*********************************
 * String compare of filenames.
 */

version (Windows)
{
    extern (C)
    {
        int stricmp(const(char)*, const(char)*) pure nothrow @nogc;
        int memicmp(const(void)*, const(void)*, size_t) pure nothrow @nogc;
    }

    alias filespeccmp = stricmp;
    alias filespecmemcmp = memicmp;

    enum DIRCHAR = '\\';

    bool ispathdelim(char c) { return c == DIRCHAR || c == ':' || c == '/'; }
}
else
{
    import core.stdc.string : strcmp, memcmp;
    alias filespeccmp = strcmp;
    alias filespecmemcmp = memcmp;

    enum DIRCHAR = '/';

    bool ispathdelim(char c) { return c == DIRCHAR; }
}

/****************************
 * Combine path and filename to form a filespec.
 * Input:
 *      path            Path, with or without trailing /
 *                      (can be NULL)
 *      filename        Cannot be NULL
 * Returns:
 *      filespec        mem_malloc'd file specification
 *      NULL            Out of memory
 */
@trusted
char *filespecaddpath(const(char)* path, const(char)* filename)
{
    char* filespec;
    size_t pathlen;

    if (!path || (pathlen = strlen(path)) == 0)
        filespec = mem_strdup(filename);
    else
    {
        filespec = cast(char*) mem_malloc(pathlen + 1 + strlen(filename) + 1);
        if (filespec)
        {
            strcpy(filespec,path);
version (Windows)
{
            if (!ispathdelim(filespec[pathlen - 1]))
                strcat(filespec,"\\");
}
else
{
            if (!ispathdelim(filespec[pathlen - 1]))
                strcat(filespec,"/");
}
            strcat(filespec,filename);
        }
    }
    return filespec;
}

/******************************* filespecrootpath **************************
 * Purpose: To expand a relative path into an absolute path.
 *
 * Side Effects: mem_frees input string.
 *
 * Returns: mem_malloced string with absolute path.
 *          NULL if some failure.
 */

version (Windows)
    extern (C) char* getcwd(char*, size_t);
else
{
    import core.sys.posix.unistd: getcwd;
}

@trusted
char *filespecrootpath(char* filespec)
{
    char *cwd;
    char *cwd_t;
    char *p;
    char *p2;

    if (!filespec)
        return filespec;
version (Windows)
{
    // if already absolute (with \ or drive:) ...
    if (*filespec == DIRCHAR || (isalpha(*filespec) && *(filespec+1) == ':'))
        return filespec;        //      ... return input string
}
else
{
    if (*filespec == DIRCHAR)   // already absolute ...
        return filespec;        //      ... return input string
}

    // get current working directory path
version (Windows)
{
    char[132] cwd_d = void;
    if (getcwd(cwd_d.ptr, cwd_d.length))
       cwd_t = cwd_d.ptr;
    else
       cwd_t = null;
}
else
{
    cwd_t = cast(char *)getcwd(null, 256);
}

    if (cwd_t == null)
    {
        mem_free(filespec);
        return null;    // error - path too long (more than 256 chars !)
    }
    cwd = mem_strdup(cwd_t);    // convert cwd to mem package
version (Windows)
{
}
else
{
    free(cwd_t);
}
    p = filespec;
    while (p != null)
    {
        p2 = cast(char*)strchr(p, DIRCHAR);
        if (p2 != null)
        {
            *p2 = '\0';
            if (strcmp(p, "..") == 0)   // move up cwd
                // remove last directory from cwd
                *(cast(char *)strrchr(cwd, DIRCHAR)) = '\0';
            else if (strcmp(p, ".") != 0) // not current directory
            {
                cwd_t = cwd;
                cwd = cast(char *)mem_calloc(strlen(cwd_t) + 1 + strlen(p) + 1);
                sprintf(cwd, "%s%c%s", cwd_t, DIRCHAR, p);  // add relative directory
                mem_free(cwd_t);
            }
            // else if ".", then ignore - it means current directory
            *p2 = DIRCHAR;
            p2++;
        }
        else if (strcmp(p,"..") == 0)   // move up cwd
        {
            // remove last directory from cwd
            *(cast(char *)strrchr(cwd, DIRCHAR)) = '\0';
        }
        else if (strcmp(p,".") != 0) // no more subdirectories ...
        {   // ... save remaining string
            cwd_t = cwd;
            cwd = cast(char *)mem_calloc(strlen(cwd_t) + 1 + strlen(p) + 1);
            sprintf(cwd, "%s%c%s", cwd_t, DIRCHAR, p);  // add relative directory
            mem_free(cwd_t);
        }
        p = p2;
    }
    mem_free(filespec);

    return cwd;
}

/*****************************
 * Add extension onto filespec, if one isn't already there.
 * Input:
 *      filespec        Cannot be NULL
 *      ext             Extension (without the .)
 * Returns:
 *      mem_malloc'ed string (NULL if error)
 */
@trusted
char *filespecdefaultext(const(char)* filespec, const(char)* ext)
{
    char *p;

    const(char)* pext = filespecdotext(filespec);
    if (*pext == '.')               /* if already got an extension  */
    {
        p = mem_strdup(filespec);
    }
    else
    {
        const n = pext - filespec;
        p = cast(char *) mem_malloc(n + 1 + strlen(ext) + 1);
        if (p)
        {
            memcpy(p,filespec,n);
            p[n] = '.';
            strcpy(&p[n + 1],ext);
        }
    }
    return p;
}

/**********************
 * Return string that is the dot and extension.
 * The string returned is NOT mem_malloc'ed.
 * Return pointer to the 0 at the end of filespec if dot isn't found.
 * Return NULL if filespec is NULL.
 */
@trusted
char *filespecdotext(const(char)* filespec)
{
    auto p = filespec;
    if (p)
    {
        const len = strlen(p);
        p += len;
        while (1)
        {
            if (*p == '.')
                break;
            if (p <= filespec || ispathdelim(*p))
            {   p = filespec + len;
                break;
            }
            p--;
        }
    }
    return cast(char*)p;
}

/*****************************
 * Force extension onto filespec.
 * Input:
 *      filespec        String that may or may not contain an extension
 *      ext             Extension that doesn't contain a .
 * Returns:
 *      mem_malloc'ed string (NULL if error)
 *      NULL if filespec is NULL
 *      If ext is NULL, return mem_strdup(filespec)
 */
@trusted
char *filespecforceext(const(char)* filespec, const(char)* ext)
{
    char* p;

    if (ext && *ext == '.')
        ext++;
    if ((p = cast(char *)filespec) != null)
    {
        const(char)* pext = filespecdotext(filespec);
        if (ext)
        {
            size_t n = pext - filespec;
            p = cast(char*) mem_malloc(n + 1 + strlen(ext) + 1);
            if (p)
            {
                memcpy(p, filespec, n);
                p[n] = '.';
                strcpy(&p[n + 1],ext);
            }
        }
        else
            p = mem_strdup(filespec);
    }
    return p;
}

/***********************
 * Get root name of file name.
 * That is, return a mem_strdup()'d version of the filename without
 * the .ext.
 */

char *filespecgetroot(const(char)* name)
{
    char* p = filespecdotext(name);
    const c = *p;
    *p = 0;
    char* root = mem_strdup(name);
    *p = c;
    return root;
}

/**********************
 * Return string that is the filename plus dot and extension.
 * The string returned is NOT mem_malloc'ed.
 */

@trusted
char *filespecname(const(char)* filespec)
{
    const(char)* p;

    /* Start at end of string and back up till we find the beginning
     * of the filename or a path
     */
    for (p = filespec + strlen(filespec);
         p != filespec && !ispathdelim(*(p - 1));
         p--
        )
    { }
    return cast(char *)p;
}

/************************************
 * If first character of filespec is a ~, perform tilde-expansion.
 * Output:
 *      Input filespec is mem_free'd.
 * Returns:
 *      mem_malloc'd string
 */

version (Windows)
{
    char *filespectilde(char *f) { return f; }
}
else
{
    char *filespectilde(char *);
}

/************************************
 * Expand all ~ in the given string.
 *
 * Output:
 *      Input filespec is mem_free'd.
 * Returns:
 *      mem_malloc'd string
 */

version (Windows)
{
    char *filespecmultitilde(char *f) { return f; }
}
else
{
    char *filespecmultitilde(char *);
}

/*****************************
 * Convert filespec into a backup filename appropriate for the
 * operating system. For instance, under MS-DOS path\filename.ext will
 * be converted to path\filename.bak.
 * Input:
 *      filespec        String that may or may not contain an extension
 * Returns:
 *      mem_malloc'ed string (NULL if error)
 *      NULL if filespec is NULL
 */

@trusted
char *filespecbackup(const(char)* filespec)
{
version (Windows)
{
    return filespecforceext(filespec,"BAK");
}
else
{
    char* p;
    char* f;

    // Prepend .B to file name, if it isn't already there
    if (!filespec)
        return cast(char *)filespec;
    p = filespecname(filespec);
    if (p[0] == '.' && p[1] == 'B')
        return mem_strdup(filespec);
    f = cast(char *) mem_malloc(strlen(filespec) + 2 + 1);
    if (f)
    {   strcpy(f,filespec);
        strcpy(&f[p - filespec],".B");
        strcat(f,p);
    }
    return f;
}
}

