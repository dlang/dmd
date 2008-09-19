/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.fcntl;

private import stdc.posix.config;
private import stdc.stdint;
public import stdc.stddef;          // for size_t
public import stdc.posix.sys.types; // for off_t, mode_t
public import stdc.posix.sys.stat;  // for S_IFMT, etc.

extern (C):

//
// Required
//
/*
F_DUPFD
F_GETFD
F_SETFD
F_GETFL
F_SETFL
F_GETLK
F_SETLK
F_SETLKW
F_GETOWN
F_SETOWN

FD_CLOEXEC

F_RDLCK
F_UNLCK
F_WRLCK

O_CREAT
O_EXCL
O_NOCTTY
O_TRUNC

O_APPEND
O_DSYNC
O_NONBLOCK
O_RSYNC
O_SYNC

O_ACCMODE
O_RDONLY
O_RDWR
O_WRONLY

struct flock
{
    short   l_type;
    short   l_whence;
    off_t   l_start;
    off_t   l_len;
    pid_t   l_pid;
}

int creat(in char*, mode_t);
int fcntl(int, int, ...);
int open(in char*, int, ...);
*/
version( linux )
{
    const F_DUPFD       = 0;
    const F_GETFD       = 1;
    const F_SETFD       = 2;
    const F_GETFL       = 3;
    const F_SETFL       = 4;
  static if( __USE_FILE_OFFSET64 )
  {
    const F_GETLK       = 12;
    const F_SETLK       = 13;
    const F_SETLKW      = 14;
  }
  else
  {
    const F_GETLK       = 5;
    const F_SETLK       = 6;
    const F_SETLKW      = 7;
  }
    const F_GETOWN      = 9;
    const F_SETOWN      = 8;

    const FD_CLOEXEC    = 1;

    const F_RDLCK       = 0;
    const F_UNLCK       = 2;
    const F_WRLCK       = 1;

    const O_CREAT       = 0100;
    const O_EXCL        = 0200;
    const O_NOCTTY      = 0400;
    const O_TRUNC       = 01000;

    const O_APPEND      = 02000;
    const O_NONBLOCK    = 04000;
    const O_SYNC        = 010000;
    const O_DSYNC       = O_SYNC;
    const O_RSYNC       = O_SYNC;

    const O_ACCMODE     = 0003;
    const O_RDONLY      = 00;
    const O_WRONLY      = 01;
    const O_RDWR        = 02;

    struct flock
    {
        short   l_type;
        short   l_whence;
        off_t   l_start;
        off_t   l_len;
        pid_t   l_pid;
    }

    static if( __USE_LARGEFILE64 )
    {
        int   creat64(in char*, mode_t);
        alias creat64 creat;

        int   open64(in char*, int, ...);
        alias open64 open;
    }
    else
    {
        int   creat(in char*, mode_t);
        int   open(in char*, int, ...);
    }
}
else version( darwin )
{
    const F_DUPFD       = 0;
    const F_GETFD       = 1;
    const F_SETFD       = 2;
    const F_GETFL       = 3;
    const F_SETFL       = 4;
    const F_GETOWN      = 5;
    const F_SETOWN      = 6;
    const F_GETLK       = 7;
    const F_SETLK       = 8;
    const F_SETLKW      = 9;

    const FD_CLOEXEC    = 1;

    const F_RDLCK       = 1;
    const F_UNLCK       = 2;
    const F_WRLCK       = 3;

    const O_CREAT       = 0x0200;
    const O_EXCL        = 0x0800;
    const O_NOCTTY      = 0;
    const O_TRUNC       = 0x0400;

    const O_RDONLY      = 0x0000;
    const O_WRONLY      = 0x0001;
    const O_RDWR        = 0x0002;
    const O_ACCMODE     = 0x0003;

    const O_NONBLOCK    = 0x0004;
    const O_APPEND      = 0x0008;
    const O_SYNC        = 0x0080;
    //const O_DSYNC
    //const O_RSYNC

    struct flock
    {
        off_t   l_start;
        off_t   l_len;
        pid_t   l_pid;
        short   l_type;
        short   l_whence;
    }

    int creat(in char*, mode_t);
    int open(in char*, int, ...);
}
else version( freebsd )
{
    const F_DUPFD       = 0;
    const F_GETFD       = 1;
    const F_SETFD       = 2;
    const F_GETFL       = 3;
    const F_SETFL       = 4;
    const F_GETOWN      = 5;
    const F_SETOWN      = 6;
    const F_GETLK       = 7;
    const F_SETLK       = 8;
    const F_SETLKW      = 9;

    const FD_CLOEXEC    = 1;

    const F_RDLCK       = 1;
    const F_UNLCK       = 2;
    const F_WRLCK       = 3;

    const O_CREAT       = 0x0200;
    const O_EXCL        = 0x0800;
    const O_NOCTTY      = 0;
    const O_TRUNC       = 0x0400;

    const O_RDONLY      = 0x0000;
    const O_WRONLY      = 0x0001;
    const O_RDWR        = 0x0002;
    const O_ACCMODE     = 0x0003;

    const O_NONBLOCK    = 0x0004;
    const O_APPEND      = 0x0008;
    const O_SYNC        = 0x0080;
    //const O_DSYNC
    //const O_RSYNC

    struct flock
    {
        off_t   l_start;
        off_t   l_len;
        pid_t   l_pid;
        short   l_type;
        short   l_whence;
    }

    int creat(in char*, mode_t);
    int open(in char*, int, ...);
}

//int creat(in char*, mode_t);
int fcntl(int, int, ...);
//int open(in char*, int, ...);

//
// Advisory Information (ADV)
//
/*
POSIX_FADV_NORMAL
POSIX_FADV_SEQUENTIAL
POSIX_FADV_RANDOM
POSIX_FADV_WILLNEED
POSIX_FADV_DONTNEED
POSIX_FADV_NOREUSE

int posix_fadvise(int, off_t, off_t, int);
int posix_fallocate(int, off_t, off_t);
*/
