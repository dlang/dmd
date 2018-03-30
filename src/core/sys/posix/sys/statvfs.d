/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Robert Klotzner 2012
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Robert Klotzner
 * Standards: The Open Group Base Specifications Issue 6 IEEE Std 1003.1, 2004 Edition
 */

module core.sys.posix.sys.statvfs;
private import core.stdc.config;
private import core.sys.posix.config;
public import core.sys.posix.sys.types;

version (Posix):
extern (C) :

version(CRuntime_Glibc) {
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

        int fstatvfs64 (int fildes, statvfs_t *buf) @trusted;
        alias fstatvfs64 fstatvfs;
    }
    else
    {
        int statvfs (const char * file, statvfs_t* buf);
        int fstatvfs (int fildes, statvfs_t *buf);
    }

}
else version(NetBSD)
{
    enum  _VFS_MNAMELEN = 1024;
    enum  _VFS_NAMELEN = 32;

    struct fsid_t
    {
       int[2] __fsid_val;
    }

    struct statvfs_t
    {
        c_ulong f_flag;
        c_ulong f_bsize;
        c_ulong f_frsize;
        c_ulong f_iosize;
        fsblkcnt_t f_blocks;
        fsblkcnt_t f_bfree;
        fsblkcnt_t f_bavail;
        fsblkcnt_t f_bresvd;
        fsfilcnt_t f_files;
        fsfilcnt_t f_ffree;
        fsfilcnt_t f_favail;
        fsfilcnt_t f_fresvd;
        ulong f_syncreads;
        ulong f_syncwrites;
        ulong f_asyncreads;
        ulong f_asyncwrites;
        fsid_t f_fsidx;
        c_ulong f_fsid;
        c_ulong f_namemax;
        int f_owner;
        int[4] f_spare;
        char[_VFS_NAMELEN] f_fstypename;
        char[_VFS_MNAMELEN] f_mntonname;
        char[_VFS_MNAMELEN] f_mntfromname;
    }

    enum FFlag
    {
        ST_RDONLY = 1,        /* Mount read-only.  */
        ST_NOSUID = 2
    }

    int statvfs (const char * file, statvfs_t* buf);
    int fstatvfs (int fildes, statvfs_t *buf) @trusted;
}
else version (FreeBSD)
{
    enum MFSNAMELEN = 16;
    enum MNAMELEN = 88;

    struct fsid_t
    {
       int[2] __fsid_val;
    }

    struct statfs_t
    {
        uint  f_version;               /* structure version number */
        uint  f_type;                  /* type of filesystem */
        ulong f_flags;                 /* copy of mount exported flags */
        ulong f_bsize;                 /* filesystem fragment size */
        ulong f_iosize;                /* optimal transfer block size */
        ulong f_blocks;                /* total data blocks in filesystem */
        ulong f_bfree;                 /* free blocks in filesystem */
        long  f_bavail;                /* free blocks avail to non-superuser */
        ulong f_files;                 /* total file nodes in filesystem */
        long  f_ffree;                 /* free nodes avail to non-superuser */
        ulong f_syncwrites;            /* count of sync writes since mount */
        ulong f_asyncwrites;           /* count of async writes since mount */
        ulong f_syncreads;             /* count of sync reads since mount */
        ulong f_asyncreads;            /* count of async reads since mount */
        ulong[10] f_spare;             /* unused spare */
        uint f_namemax;                /* maximum filename length */
        uint f_owner;                  /* user that mounted the filesystem */
        fsid_t f_fsid;                 /* filesystem id */
        char[80] f_charspare;          /* spare string space */
        char[MFSNAMELEN] f_fstypename; /* filesystem type name */
        char[MNAMELEN] f_mntfromname;  /* mounted filesystem */
        char[MNAMELEN] f_mntonname;    /* directory on which mounted */
    }

    enum FFlag
    {
        MNT_RDONLY = 1,          /* read only filesystem */
        MNT_SYNCHRONOUS = 2,     /* fs written synchronously */
        MNT_NOEXEC = 4,          /* can't exec from filesystem */
        MNT_NOSUID  = 8,         /* don't honor setuid fs bits */
        MNT_NFS4ACLS = 16,       /* enable NFS version 4 ACLs */
        MNT_UNION = 32,          /* union with underlying fs */
        MNT_ASYNC = 64,          /* fs written asynchronously */
        MNT_SUIDDIR = 128,       /* special SUID dir handling */
        MNT_SOFTDEP = 256,       /* using soft updates */
        MNT_NOSYMFOLLOW = 512,   /* do not follow symlinks */
        MNT_GJOURNAL = 1024,     /* GEOM journal support enabled */
        MNT_MULTILABEL = 2048,   /* MAC support for objects */
        MNT_ACLS = 4096,         /* ACL support enabled */
        MNT_NOATIME = 8192,      /* dont update file access time */
        MNT_NOCLUSTERR = 16384,  /* disable cluster read */
        MNT_NOCLUSTERW = 32768,  /* disable cluster write */
        MNT_SUJ = 65536,         /* using journaled soft updates */
        MNT_AUTOMOUNTED = 131072 /* mounted by automountd(8) */
    }

    int statfs(const char* file, statfs_t* buf);
    int fstatfs(int fildes, statfs_t* buf) @trusted;
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
    int fstatvfs (int fildes, statvfs_t *buf) @trusted;
}
