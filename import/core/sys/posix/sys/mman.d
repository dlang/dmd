/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.sys.mman;

private import core.sys.posix.config;
public import core.stdc.stddef;          // for size_t
public import core.sys.posix.sys.types; // for off_t, mode_t

extern (C):

//
// Advisory Information (ADV)
//
/*
int posix_madvise(void*, size_t, int);
*/

//
// Advisory Information and either Memory Mapped Files or Shared Memory Objects (MC1)
//
/*
POSIX_MADV_NORMAL
POSIX_MADV_SEQUENTIAL
POSIX_MADV_RANDOM
POSIX_MADV_WILLNEED
POSIX_MADV_DONTNEED
*/

version( linux )
{
    const POSIX_MADV_NORMAL     = 0;
    const POSIX_MADV_RANDOM     = 1;
    const POSIX_MADV_SEQUENTIAL = 2;
    const POSIX_MADV_WILLNEED   = 3;
    const POSIX_MADV_DONTNEED   = 4;
}
else version( OSX )
{
    const POSIX_MADV_NORMAL     = 0;
    const POSIX_MADV_RANDOM     = 1;
    const POSIX_MADV_SEQUENTIAL = 2;
    const POSIX_MADV_WILLNEED   = 3;
    const POSIX_MADV_DONTNEED   = 4;
}
else version( freebsd )
{
    const POSIX_MADV_NORMAL     = 0;
    const POSIX_MADV_RANDOM     = 1;
    const POSIX_MADV_SEQUENTIAL = 2;
    const POSIX_MADV_WILLNEED   = 3;
    const POSIX_MADV_DONTNEED   = 4;
}

//
// Memory Mapped Files, Shared Memory Objects, or Memory Protection (MC2)
//
/*
PROT_READ
PROT_WRITE
PROT_EXEC
PROT_NONE
*/

version( linux )
{
    const PROT_NONE     = 0x0;
    const PROT_READ     = 0x1;
    const PROT_WRITE    = 0x2;
    const PROT_EXEC     = 0x4;
}
else version( OSX )
{
    const PROT_NONE     = 0x00;
    const PROT_READ     = 0x01;
    const PROT_WRITE    = 0x02;
    const PROT_EXEC     = 0x04;
}
else version( freebsd )
{
    const PROT_NONE     = 0x00;
    const PROT_READ     = 0x01;
    const PROT_WRITE    = 0x02;
    const PROT_EXEC     = 0x04;
}

//
// Memory Mapped Files, Shared Memory Objects, or Typed Memory Objects (MC3)
//
/*
void* mmap(void*, size_t, int, int, int, off_t);
int munmap(void*, size_t);
*/

version( linux )
{
    //void* mmap(void*, size_t, int, int, int, off_t);
    int   munmap(void*, size_t);

  static if( __USE_LARGEFILE64 )
  {
    void* mmap64(void*, size_t, int, int, int, off_t);
    alias mmap64 mmap;
  }
  else
  {
    void* mmap(void*, size_t, int, int, int, off_t);
  }
}
else version( OSX )
{
    void* mmap(void*, size_t, int, int, int, off_t);
    int   munmap(void*, size_t);
}
else version( freebsd )
{
    void* mmap(void*, size_t, int, int, int, off_t);
    int   munmap(void*, size_t);
}

//
// Memory Mapped Files (MF)
//
/*
MAP_SHARED (MF|SHM)
MAP_PRIVATE (MF|SHM)
MAP_FIXED  (MF|SHM)
MAP_FAILED (MF|SHM)

MS_ASYNC (MF|SIO)
MS_SYNC (MF|SIO)
MS_INVALIDATE (MF|SIO)

int msync(void*, size_t, int); (MF|SIO)
*/

version( linux )
{
    const MAP_SHARED    = 0x01;
    const MAP_PRIVATE   = 0x02;
    const MAP_FIXED     = 0x10;
    const MAP_ANON      = 0x20; // non-standard

    const MAP_FAILED    = cast(void*) -1;

    enum
    {
        MS_ASYNC        = 1,
        MS_SYNC         = 4,
        MS_INVALIDATE   = 2
    }

    int msync(void*, size_t, int);
}
else version( OSX )
{
    const MAP_SHARED    = 0x0001;
    const MAP_PRIVATE   = 0x0002;
    const MAP_FIXED     = 0x0010;
    const MAP_ANON      = 0x1000; // non-standard

    const MAP_FAILED    = cast(void*)-1;

    const MS_ASYNC      = 0x0001;
    const MS_INVALIDATE = 0x0002;
    const MS_SYNC       = 0x0010;

    int msync(void*, size_t, int);
}
else version( freebsd )
{
    const MAP_SHARED    = 0x0001;
    const MAP_PRIVATE   = 0x0002;
    const MAP_FIXED     = 0x0010;
    const MAP_ANON      = 0x1000; // non-standard

    const MAP_FAILED    = cast(void*)-1;

    const MS_SYNC       = 0x0000;
    const MS_ASYNC      = 0x0001;
    const MS_INVALIDATE = 0x0002;

    int msync(void*, size_t, int);
}

//
// Process Memory Locking (ML)
//
/*
MCL_CURRENT
MCL_FUTURE

int mlockall(int);
int munlockall();
*/

version( linux )
{
    const MCL_CURRENT   = 1;
    const MCL_FUTURE    = 2;

    int mlockall(int);
    int munlockall();

}
else version( OSX )
{
    const MCL_CURRENT   = 0x0001;
    const MCL_FUTURE    = 0x0002;

    int mlockall(int);
    int munlockall();
}
else version( freebsd )
{
    const MCL_CURRENT   = 0x0001;
    const MCL_FUTURE    = 0x0002;

    int mlockall(int);
    int munlockall();
}

//
// Range Memory Locking (MLR)
//
/*
int mlock(in void*, size_t);
int munlock(in void*, size_t);
*/

version( linux )
{
    int mlock(in void*, size_t);
    int munlock(in void*, size_t);
}
else version( OSX )
{
    int mlock(in void*, size_t);
    int munlock(in void*, size_t);
}
else version( freebsd )
{
    int mlock(in void*, size_t);
    int munlock(in void*, size_t);
}

//
// Memory Protection (MPR)
//
/*
int mprotect(void*, size_t, int);
*/

version( OSX )
{
    int mprotect(void*, size_t, int);
}
else version( freebsd )
{
    int mprotect(void*, size_t, int);
}

//
// Shared Memory Objects (SHM)
//
/*
int shm_open(in char*, int, mode_t);
int shm_unlink(in char*);
*/

version( linux )
{
    int shm_open(in char*, int, mode_t);
    int shm_unlink(in char*);
}
else version( OSX )
{
    int shm_open(in char*, int, mode_t);
    int shm_unlink(in char*);
}
else version( freebsd )
{
    int shm_open(in char*, int, mode_t);
    int shm_unlink(in char*);
}

//
// Typed Memory Objects (TYM)
//
/*
POSIX_TYPED_MEM_ALLOCATE
POSIX_TYPED_MEM_ALLOCATE_CONTIG
POSIX_TYPED_MEM_MAP_ALLOCATABLE

struct posix_typed_mem_info
{
    size_t posix_tmi_length;
}

int posix_mem_offset(in void*, size_t, off_t *, size_t *, int *);
int posix_typed_mem_get_info(int, struct posix_typed_mem_info *);
int posix_typed_mem_open(in char*, int, int);
*/
