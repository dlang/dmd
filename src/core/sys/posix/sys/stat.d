/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.sys.stat;

private import core.sys.posix.config;
private import core.stdc.stdint;
private import core.sys.posix.time;     // for timespec
public import core.stdc.stddef;          // for size_t
public import core.sys.posix.sys.types; // for off_t, mode_t

extern (C):

//
// Required
//
/*
struct stat
{
    dev_t   st_dev;
    ino_t   st_ino;
    mode_t  st_mode;
    nlink_t st_nlink;
    uid_t   st_uid;
    gid_t   st_gid;
    off_t   st_size;
    time_t  st_atime;
    time_t  st_mtime;
    time_t  st_ctime;
}

S_IRWXU
    S_IRUSR
    S_IWUSR
    S_IXUSR
S_IRWXG
    S_IRGRP
    S_IWGRP
    S_IXGRP
S_IRWXO
    S_IROTH
    S_IWOTH
    S_IXOTH
S_ISUID
S_ISGID
S_ISVTX

S_ISBLK(m)
S_ISCHR(m)
S_ISDIR(m)
S_ISFIFO(m)
S_ISREG(m)
S_ISLNK(m)
S_ISSOCK(m)

S_TYPEISMQ(buf)
S_TYPEISSEM(buf)
S_TYPEISSHM(buf)

int    chmod(in char*, mode_t);
int    fchmod(int, mode_t);
int    fstat(int, stat*);
int    lstat(in char*, stat*);
int    mkdir(in char*, mode_t);
int    mkfifo(in char*, mode_t);
int    stat(in char*, stat*);
mode_t umask(mode_t);
*/

version( linux )
{
    static if( __USE_LARGEFILE64 )
    {
        private alias uint _pad_t;
    }
    else
    {
        private alias ushort _pad_t;
    }

    struct stat_t
    {
        dev_t       st_dev;
        _pad_t      __pad1;
      static if( __USE_FILE_OFFSET64 )
      {
        ino_t       __st_ino;
      }
      else
      {
        ino_t       st_ino;
      }
        mode_t      st_mode;
        nlink_t     st_nlink;
        uid_t       st_uid;
        gid_t       st_gid;
        dev_t       st_rdev;
        _pad_t      __pad2;
        off_t       st_size;
        blksize_t   st_blksize;
        blkcnt_t    st_blocks;
      static if( false /*__USE_MISC*/ ) // true if _BSD_SOURCE || _SVID_SOURCE
      {
        timespec    st_atim;
        timespec    st_mtim;
        timespec    st_ctim;
        alias st_atim.tv_sec st_atime;
        alias st_mtim.tv_sec st_mtime;
        alias st_ctim.tv_sec st_ctime;
      }
      else
      {
        time_t      st_atime;
        c_ulong     st_atimensec;
        time_t      st_mtime;
        c_ulong     st_mtimensec;
        time_t      st_ctime;
        c_ulong     st_ctimensec;
      }
      static if( __USE_FILE_OFFSET64 )
      {
        ino_t       st_ino;
      }
      else
      {
        c_ulong     __unused4;
        c_ulong     __unused5;
      }
    }

    enum S_IRUSR    = 0400;
    enum S_IWUSR    = 0200;
    enum S_IXUSR    = 0100;
    enum S_IRWXU    = S_IRUSR | S_IWUSR | S_IXUSR;

    enum S_IRGRP    = S_IRUSR >> 3;
    enum S_IWGRP    = S_IWUSR >> 3;
    enum S_IXGRP    = S_IXUSR >> 3;
    enum S_IRWXG    = S_IRWXU >> 3;

    enum S_IROTH    = S_IRGRP >> 3;
    enum S_IWOTH    = S_IWGRP >> 3;
    enum S_IXOTH    = S_IXGRP >> 3;
    enum S_IRWXO    = S_IRWXG >> 3;

    enum S_ISUID    = 04000;
    enum S_ISGID    = 02000;
    enum S_ISVTX    = 01000;

    private
    {
        extern (D) bool S_ISTYPE( mode_t mode, uint mask )
        {
            return ( mode & S_IFMT ) == mask;
        }
    }

    extern (D) bool S_ISBLK( mode_t mode )  { return S_ISTYPE( mode, S_IFBLK );  }
    extern (D) bool S_ISCHR( mode_t mode )  { return S_ISTYPE( mode, S_IFCHR );  }
    extern (D) bool S_ISDIR( mode_t mode )  { return S_ISTYPE( mode, S_IFDIR );  }
    extern (D) bool S_ISFIFO( mode_t mode ) { return S_ISTYPE( mode, S_IFIFO );  }
    extern (D) bool S_ISREG( mode_t mode )  { return S_ISTYPE( mode, S_IFREG );  }
    extern (D) bool S_ISLNK( mode_t mode )  { return S_ISTYPE( mode, S_IFLNK );  }
    extern (D) bool S_ISSOCK( mode_t mode ) { return S_ISTYPE( mode, S_IFSOCK ); }

    static if( true /*__USE_POSIX199309*/ )
    {
        extern bool S_TYPEISMQ( stat_t* buf )  { return false; }
        extern bool S_TYPEISSEM( stat_t* buf ) { return false; }
        extern bool S_TYPEISSHM( stat_t* buf ) { return false; }
    }
}
else version( OSX )
{
    struct stat_t
    {
        dev_t       st_dev;
        ino_t       st_ino;
        mode_t      st_mode;
        nlink_t     st_nlink;
        uid_t       st_uid;
        gid_t       st_gid;
        dev_t       st_rdev;
      static if( false /*!_POSIX_C_SOURCE || _DARWIN_C_SOURCE*/ )
      {
          timespec  st_atimespec;
          timespec  st_mtimespec;
          timespec  st_ctimespec;
      }
      else
      {
        time_t      st_atime;
        c_long      st_atimensec;
        time_t      st_mtime;
        c_long      st_mtimensec;
        time_t      st_ctime;
        c_long      st_ctimensec;
      }
        off_t       st_size;
        blkcnt_t    st_blocks;
        blksize_t   st_blksize;
        uint        st_flags;
        uint        st_gen;
        int         st_lspare;
        long        st_qspare[2];
    }

    enum S_IRUSR    = 0400;
    enum S_IWUSR    = 0200;
    enum S_IXUSR    = 0100;
    enum S_IRWXU    = S_IRUSR | S_IWUSR | S_IXUSR;

    enum S_IRGRP    = S_IRUSR >> 3;
    enum S_IWGRP    = S_IWUSR >> 3;
    enum S_IXGRP    = S_IXUSR >> 3;
    enum S_IRWXG    = S_IRWXU >> 3;

    enum S_IROTH    = S_IRGRP >> 3;
    enum S_IWOTH    = S_IWGRP >> 3;
    enum S_IXOTH    = S_IXGRP >> 3;
    enum S_IRWXO    = S_IRWXG >> 3;

    enum S_ISUID    = 04000;
    enum S_ISGID    = 02000;
    enum S_ISVTX    = 01000;

    private
    {
        extern (D) bool S_ISTYPE( mode_t mode, uint mask )
        {
            return ( mode & S_IFMT ) == mask;
        }
    }

    extern (D) bool S_ISBLK( mode_t mode )  { return S_ISTYPE( mode, S_IFBLK );  }
    extern (D) bool S_ISCHR( mode_t mode )  { return S_ISTYPE( mode, S_IFCHR );  }
    extern (D) bool S_ISDIR( mode_t mode )  { return S_ISTYPE( mode, S_IFDIR );  }
    extern (D) bool S_ISFIFO( mode_t mode ) { return S_ISTYPE( mode, S_IFIFO );  }
    extern (D) bool S_ISREG( mode_t mode )  { return S_ISTYPE( mode, S_IFREG );  }
    extern (D) bool S_ISLNK( mode_t mode )  { return S_ISTYPE( mode, S_IFLNK );  }
    extern (D) bool S_ISSOCK( mode_t mode ) { return S_ISTYPE( mode, S_IFSOCK ); }
}
else version( FreeBSD )
{
    struct stat_t
    {
        dev_t       st_dev;
        ino_t       st_ino;
        mode_t      st_mode;
        nlink_t     st_nlink;
        uid_t       st_uid;
        gid_t       st_gid;
        dev_t       st_rdev;

        time_t      st_atime;
        c_long      __st_atimensec;
        time_t      st_mtime;
        c_long      __st_mtimensec;
        time_t      st_ctime;
        c_long      __st_ctimensec;

        off_t       st_size;
        blkcnt_t    st_blocks;
        blksize_t   st_blksize;
        fflags_t    st_flags;
        uint        st_gen;
        int         st_lspare;

        time_t      st_birthtime;
        c_long      st_birthtimensec;

        ubyte[16 - timespec.sizeof] padding;
    }

    enum S_IRUSR    = 0000400;
    enum S_IWUSR    = 0000200;
    enum S_IXUSR    = 0000100;
    enum S_IRWXU    = 0000700;

    enum S_IRGRP    = 0000040;
    enum S_IWGRP    = 0000020;
    enum S_IXGRP    = 0000010;
    enum S_IRWXG    = 0000070;

    enum S_IROTH    = 0000004;
    enum S_IWOTH    = 0000002;
    enum S_IXOTH    = 0000001;
    enum S_IRWXO    = 0000007;

    enum S_ISUID    = 0004000;
    enum S_ISGID    = 0002000;
    enum S_ISVTX    = 0001000;

    private
    {
        extern (D) bool S_ISTYPE( mode_t mode, uint mask )
        {
            return ( mode & S_IFMT ) == mask;
        }
    }

    extern (D) bool S_ISBLK( mode_t mode )  { return S_ISTYPE( mode, S_IFBLK );  }
    extern (D) bool S_ISCHR( mode_t mode )  { return S_ISTYPE( mode, S_IFCHR );  }
    extern (D) bool S_ISDIR( mode_t mode )  { return S_ISTYPE( mode, S_IFDIR );  }
    extern (D) bool S_ISFIFO( mode_t mode ) { return S_ISTYPE( mode, S_IFIFO );  }
    extern (D) bool S_ISREG( mode_t mode )  { return S_ISTYPE( mode, S_IFREG );  }
    extern (D) bool S_ISLNK( mode_t mode )  { return S_ISTYPE( mode, S_IFLNK );  }
    extern (D) bool S_ISSOCK( mode_t mode ) { return S_ISTYPE( mode, S_IFSOCK ); }
}

version( Posix )
{
    int    chmod(in char*, mode_t);
    int    fchmod(int, mode_t);
    //int    fstat(int, stat_t*);
    //int    lstat(in char*, stat_t*);
    int    mkdir(in char*, mode_t);
    int    mkfifo(in char*, mode_t);
    //int    stat(in char*, stat_t*);
    mode_t umask(mode_t);
}

version( linux )
{
  static if( __USE_LARGEFILE64 )
  {
    int   fstat64(int, stat_t*);
    alias fstat64 fstat;

    int   lstat64(in char*, stat_t*);
    alias lstat64 lstat;

    int   stat64(in char*, stat_t*);
    alias stat64 stat;
  }
  else
  {
    int   fstat(int, stat_t*);
    int   lstat(in char*, stat_t*);
    int   stat(in char*, stat_t*);
  }
}
else version( Posix )
{
    int   fstat(int, stat_t*);
    int   lstat(in char*, stat_t*);
    int   stat(in char*, stat_t*);
}

//
// Typed Memory Objects (TYM)
//
/*
S_TYPEISTMO(buf)
*/

//
// XOpen (XSI)
//
/*
S_IFMT
S_IFBLK
S_IFCHR
S_IFIFO
S_IFREG
S_IFDIR
S_IFLNK
S_IFSOCK

int mknod(in 3char*, mode_t, dev_t);
*/

version( linux )
{
    enum S_IFMT     = 0170000;
    enum S_IFBLK    = 0060000;
    enum S_IFCHR    = 0020000;
    enum S_IFIFO    = 0010000;
    enum S_IFREG    = 0100000;
    enum S_IFDIR    = 0040000;
    enum S_IFLNK    = 0120000;
    enum S_IFSOCK   = 0140000;

    int mknod(in char*, mode_t, dev_t);
}
else version( OSX )
{
    enum S_IFMT     = 0170000;
    enum S_IFBLK    = 0060000;
    enum S_IFCHR    = 0020000;
    enum S_IFIFO    = 0010000;
    enum S_IFREG    = 0100000;
    enum S_IFDIR    = 0040000;
    enum S_IFLNK    = 0120000;
    enum S_IFSOCK   = 0140000;

    int mknod(in char*, mode_t, dev_t);
}
else version( FreeBSD )
{
    enum S_IFMT     = 0170000;
    enum S_IFBLK    = 0060000;
    enum S_IFCHR    = 0020000;
    enum S_IFIFO    = 0010000;
    enum S_IFREG    = 0100000;
    enum S_IFDIR    = 0040000;
    enum S_IFLNK    = 0120000;
    enum S_IFSOCK   = 0140000;

    int mknod(in char*, mode_t, dev_t);
}
