/**
 * D header file to interface with the
 * $(HTTP pubs.opengroup.org/onlinepubs/9699919799/basedefs/aio.h.html, Posix AIO API).
 *
 * Copyright: Copyright D Language Foundation 2018.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   $(HTTPS github.com/darredevil, Alexandru Razvan Caciulescu)
 */
module core.sys.posix.aio;

private import core.sys.posix.signal;

version (Posix):

extern (C):
@system:
@nogc:
nothrow:

version (CRuntime_Glibc)
{
    version (X86_64)
    {
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
    }
    else
        static assert(0);
}
else
    static assert(false, "Unsupported platform");

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
int aio_error(const(aiocb)* aiocbp);
ssize_t aio_return(const(aiocb)* aiocbp);
int aio_suspend(const(aiocb*)* aiocb_list, int nitems, const(timespec)* timeout);
int aio_cancel(int fd, aiocb *aiocbp);
int lio_listio(int mode, const(aiocb*)* aiocb_list, int nitems, sigevent *sevp);
