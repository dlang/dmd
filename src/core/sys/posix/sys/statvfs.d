/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Robert Klotzner 2012
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Robert Klotzner
 * Standards: The Open Group Base Specifications Issue 6 IEEE Std 1003.1, 2004 Edition
 */

module core.sys.posix.sys.statvfs;
private import core.stdc.config;
private import core.sys.posix.config;
public import core.sys.posix.sys.types;

version (Posix):
extern (C) :

version(linux) {
    static if(__WORDSIZE == 32) 
    {
        version=_STATVFSBUF_F_UNUSED;
    }
    struct statvfs_t
    {
        c_ulong f_bsize;
        c_ulong f_frsize;
        fsblkcnt_t f_blocks;
        fsblkcnt_t f_bfree;
        fsblkcnt_t f_bavail;
        fsfilcnt_t f_files;
        fsfilcnt_t f_ffree;
        fsfilcnt_t f_favail;
        c_ulong f_fsid;
        version(_STATVFSBUF_F_UNUSED) 
        {
            int __f_unused;
        }
        c_ulong f_flag;
        c_ulong f_namemax;
        int[6] __f_spare;
    }
    /* Definitions for the flag in `f_flag'.  These definitions should be
      kept in sync with the definitions in <sys/mount.h>.  */
    static if(__USE_GNU) 
    {
        enum FFlag
        {
            ST_RDONLY = 1,        /* Mount read-only.  */
            ST_NOSUID = 2,
            ST_NODEV = 4,         /* Disallow access to device special files.  */
            ST_NOEXEC = 8,        /* Disallow program execution.  */
            ST_SYNCHRONOUS = 16,      /* Writes are synced at once.  */
            ST_MANDLOCK = 64,     /* Allow mandatory locks on an FS.  */
            ST_WRITE = 128,       /* Write on file/directory/symlink.  */
            ST_APPEND = 256,      /* Append-only file.  */
            ST_IMMUTABLE = 512,       /* Immutable file.  */
            ST_NOATIME = 1024,        /* Do not update access times.  */
            ST_NODIRATIME = 2048,     /* Do not update directory access times.  */
            ST_RELATIME = 4096        /* Update atime relative to mtime/ctime.  */

        }
    }  /* Use GNU.  */
    else 
    { // Posix defined:
        enum FFlag
        {
            ST_RDONLY = 1,        /* Mount read-only.  */
            ST_NOSUID = 2
        }
    }

    static if( __USE_FILE_OFFSET64 )
    {
        int statvfs64 (const char * file, statvfs_t* buf);
        alias statvfs64 statvfs;

        int fstatvfs64 (int fildes, statvfs_t *buf);
        alias fstatvfs64 fstatvfs;
    }
    else
    {
        int statvfs (const char * file, statvfs_t* buf);
        int fstatvfs (int fildes, statvfs_t *buf);
    }

}
else
{
    struct statvfs_t
    {
        c_ulong f_bsize;
        c_ulong f_frsize;
        fsblkcnt_t f_blocks;
        fsblkcnt_t f_bfree;
        fsblkcnt_t f_bavail;
        fsfilcnt_t f_files;
        fsfilcnt_t f_ffree;
        fsfilcnt_t f_favail;
        c_ulong f_fsid;
        c_ulong f_flag;
        c_ulong f_namemax;
    }

    enum FFlag
    {
        ST_RDONLY = 1,        /* Mount read-only.  */
        ST_NOSUID = 2
    }

    int statvfs (const char * file, statvfs_t* buf);
    int fstatvfs (int fildes, statvfs_t *buf);
}
