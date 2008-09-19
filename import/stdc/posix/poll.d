/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.poll;

private import stdc.posix.config;

extern (C):

//
// XOpen (XSI)
//
/*
struct pollfd
{
    int     fd;
    short   events;
    short   revents;
}

nfds_t

POLLIN
POLLRDNORM
POLLRDBAND
POLLPRI
POLLOUT
POLLWRNORM
POLLWRBAND
POLLERR
POLLHUP
POLLNVAL

int poll(pollfd[], nfds_t, int);
*/

version( linux )
{
    struct pollfd
    {
        int     fd;
        short   events;
        short   revents;
    }

    alias c_ulong nfds_t;

    const POLLIN        = 0x001;
    const POLLRDNORM    = 0x040;
    const POLLRDBAND    = 0x080;
    const POLLPRI       = 0x002;
    const POLLOUT       = 0x004;
    const POLLWRNORM    = 0x100;
    const POLLWRBAND    = 0x200;
    const POLLERR       = 0x008;
    const POLLHUP       = 0x010;
    const POLLNVAL      = 0x020;

    int poll(pollfd*, nfds_t, int);
}
else version( darwin )
{
    struct pollfd
    {
        int     fd;
        short   events;
        short   revents;
    };

    alias uint nfds_t;

    enum
    {
        POLLIN      = 0x0001,
        POLLPRI     = 0x0002,
        POLLOUT     = 0x0004,
        POLLRDNORM  = 0x0040,
        POLLWRNORM  = POLLOUT,
        POLLRDBAND  = 0x0080,
        POLLWRBAND  = 0x0100,
        POLLEXTEND  = 0x0200,
        POLLATTRIB  = 0x0400,
        POLLNLINK   = 0x0800,
        POLLWRITE   = 0x1000,
        POLLERR     = 0x0008,
        POLLHUP     = 0x0010,
        POLLNVAL    = 0x0020,

        POLLSTANDARD = (POLLIN|POLLPRI|POLLOUT|POLLRDNORM|POLLRDBAND|
                        POLLWRBAND|POLLERR|POLLHUP|POLLNVAL)
    }

    int poll(pollfd*, nfds_t, int);
}
else version( freebsd )
{
    struct pollfd
    {
        int     fd;
        short   events;
        short   revents;
    };

    alias uint nfds_t;

    enum
    {
        POLLIN      = 0x0001,
        POLLPRI     = 0x0002,
        POLLOUT     = 0x0004,
        POLLRDNORM  = 0x0040,
        POLLWRNORM  = POLLOUT,
        POLLRDBAND  = 0x0080,
        POLLWRBAND  = 0x0100,
        //POLLEXTEND  = 0x0200,
        //POLLATTRIB  = 0x0400,
        //POLLNLINK   = 0x0800,
        //POLLWRITE   = 0x1000,
        POLLERR     = 0x0008,
        POLLHUP     = 0x0010,
        POLLNVAL    = 0x0020,

        POLLSTANDARD = (POLLIN|POLLPRI|POLLOUT|POLLRDNORM|POLLRDBAND|
        POLLWRBAND|POLLERR|POLLHUP|POLLNVAL)
    }

    int poll(pollfd*, nfds_t, int);
}
