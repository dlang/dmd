/**
 * D header file to interface with the Linux aio API (http://man7.org/linux/man-pages/man7/aio.7.html).
 * Available since Linux 2.6
 *
 * Copyright: Copyright D Language Foundation 2018.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Alexandru Razvan Caciulescu (github.com/darredevil)
 */
module core.sys.posix.aio;

private import core.sys.posix.signal;

version (CRuntime_Glibc):
version (X86_64):

extern (C):
@system:
@nogc:
nothrow:

struct aiocb
{
    int aio_fildes;
    int aio_lio_opcode;
    int aio_reqprio;
    void *aio_buf;   //volatile
    size_t aio_nbytes;
    sigevent aio_sigevent;

    ubyte[24] internal_members_padding;
    off_t aio_offset;
    ubyte[32] __glibc_reserved;
}

/* Return values of cancelation function.  */
enum
{
    AIO_CANCELED,
    AIO_NOTCANCELED,
    AIO_ALLDONE
};

/* Operation codes for `aio_lio_opcode'.  */
enum
{
    LIO_READ,
    LIO_WRITE,
    LIO_NOP
};

/* Synchronization options for `lio_listio' function.  */
enum
{
    LIO_WAIT,
    LIO_NOWAIT
};

int aio_read(aiocb *aiocbp);
int aio_write(aiocb *aiocbp);
int aio_fsync(int op, aiocb *aiocbp);
int aio_error(aiocb *aiocbp);
ssize_t aio_return(aiocb *aiocbp);
int aio_suspend(aiocb*[] aiocb_list, int nitems, timespec *timeout);
int aio_cancel(int fd, aiocb *aiocbp);
int lio_listio(int mode, aiocb*[] aiocb_list, int nitems, sigevent *sevp);
