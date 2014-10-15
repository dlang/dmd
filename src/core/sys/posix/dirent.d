/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly,
              Alex Rønne Petersn
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.dirent;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for ino_t

version (Posix):
extern (C):
nothrow:
@nogc:

//
// Required
//
/*
DIR

struct dirent
{
    char[] d_name;
}

int     closedir(DIR*);
DIR*    opendir(in char*);
dirent* readdir(DIR*);
void    rewinddir(DIR*);
*/

version( linux )
{
    // NOTE: The following constants are non-standard Linux definitions
    //       for dirent.d_type.
    enum
    {
        DT_UNKNOWN  = 0,
        DT_FIFO     = 1,
        DT_CHR      = 2,
        DT_DIR      = 4,
        DT_BLK      = 6,
        DT_REG      = 8,
        DT_LNK      = 10,
        DT_SOCK     = 12,
        DT_WHT      = 14
    }

    struct dirent
    {
        ino_t       d_ino;
        off_t       d_off;
        ushort      d_reclen;
        ubyte       d_type;
        char[256]   d_name;
    }

    struct DIR
    {
        // Managed by OS
    }

    static if( __USE_FILE_OFFSET64 )
    {
        dirent* readdir64(DIR*);
        alias   readdir64 readdir;
    }
    else
    {
        dirent* readdir(DIR*);
    }
}
else version( OSX )
{
    enum
    {
        DT_UNKNOWN  = 0,
        DT_FIFO     = 1,
        DT_CHR      = 2,
        DT_DIR      = 4,
        DT_BLK      = 6,
        DT_REG      = 8,
        DT_LNK      = 10,
        DT_SOCK     = 12,
        DT_WHT      = 14
    }

    align(4)
    struct dirent
    {
        ino_t       d_ino;
        ushort      d_reclen;
        ubyte       d_type;
        ubyte       d_namlen;
        char[256]   d_name;
    }

    struct DIR
    {
        // Managed by OS
    }

    dirent* readdir(DIR*);
}
else version( FreeBSD )
{
    enum
    {
        DT_UNKNOWN  = 0,
        DT_FIFO     = 1,
        DT_CHR      = 2,
        DT_DIR      = 4,
        DT_BLK      = 6,
        DT_REG      = 8,
        DT_LNK      = 10,
        DT_SOCK     = 12,
        DT_WHT      = 14
    }

    align(4)
    struct dirent
    {
        uint      d_fileno;
        ushort    d_reclen;
        ubyte     d_type;
        ubyte     d_namlen;
        char[256] d_name;
    }

    alias void* DIR;

    dirent* readdir(DIR*);
}
else version (Solaris)
{
    struct dirent
    {
        ino_t d_ino;
        off_t d_off;
        ushort d_reclen;
        char[1] d_name;
    }

    struct DIR
    {
        int dd_fd;
        int dd_loc;
        int dd_size;
        char* dd_buf;
    }

    static if (__USE_LARGEFILE64)
    {
        dirent* readdir64(DIR*);
        alias readdir64 readdir;
    }
    else
    {
        dirent* readdir(DIR*);
    }
}
else version( Android )
{
    enum
    {
        DT_UNKNOWN  = 0,
        DT_FIFO     = 1,
        DT_CHR      = 2,
        DT_DIR      = 4,
        DT_BLK      = 6,
        DT_REG      = 8,
        DT_LNK      = 10,
        DT_SOCK     = 12,
        DT_WHT      = 14
    }

    version (X86)
    {
        struct dirent
        {
            ulong       d_ino;
            long        d_off;
            ushort      d_reclen;
            ubyte       d_type;
            char[256]   d_name;
        }
    }
    else
    {
        static assert(false, "Architecture not supported.");
    }

    struct DIR
    {
    }

    dirent* readdir(DIR*);
}
else
{
    static assert(false, "Unsupported platform");
}

int     closedir(DIR*);
DIR*    opendir(in char*);
//dirent* readdir(DIR*);
void    rewinddir(DIR*);

//
// Thread-Safe Functions (TSF)
//
/*
int readdir_r(DIR*, dirent*, dirent**);
*/

version( linux )
{
  static if( __USE_LARGEFILE64 )
  {
    int   readdir64_r(DIR*, dirent*, dirent**);
    alias readdir64_r readdir_r;
  }
  else
  {
    int readdir_r(DIR*, dirent*, dirent**);
  }
}
else version( OSX )
{
    int readdir_r(DIR*, dirent*, dirent**);
}
else version( FreeBSD )
{
    int readdir_r(DIR*, dirent*, dirent**);
}
else version (Solaris)
{
    static if (__USE_LARGEFILE64)
    {
        int readdir64_r(DIR*, dirent*, dirent**);
        alias readdir64_r readdir_r;
    }
    else
    {
        int readdir_r(DIR*, dirent*, dirent**);
    }
}
else version( Android )
{
    int readdir_r(DIR*, dirent*, dirent**);
}
else
{
    static assert(false, "Unsupported platform");
}

//
// XOpen (XSI)
//
/*
void   seekdir(DIR*, c_long);
c_long telldir(DIR*);
*/

version( linux )
{
    void   seekdir(DIR*, c_long);
    c_long telldir(DIR*);
}
else version( FreeBSD )
{
    void   seekdir(DIR*, c_long);
    c_long telldir(DIR*);
}
else version (OSX)
{
}
else version (Solaris)
{
    c_long telldir(DIR*);
    void seekdir(DIR*, c_long);
}
else version (Android)
{
}
else
{
    static assert(false, "Unsupported platform");
}
