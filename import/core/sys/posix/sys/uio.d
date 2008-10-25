/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.sys.uio;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for ssize_t, size_t

extern (C):

//
// Required
//
/*
struct iovec
{
    void*  iov_base;
    size_t iov_len;
}

ssize_t // from core.sys.posix.sys.types
size_t  // from core.sys.posix.sys.types

ssize_t readv(int, in iovec*, int);
ssize_t writev(int, in iovec*, int);
*/

version( linux )
{
    struct iovec
    {
        void*  iov_base;
        size_t iov_len;
    }

    ssize_t readv(int, in iovec*, int);
    ssize_t writev(int, in iovec*, int);
}
else version( darwin )
{
    struct iovec
    {
        void*  iov_base;
        size_t iov_len;
    }

    ssize_t readv(int, in iovec*, int);
    ssize_t writev(int, in iovec*, int);
}
else version( freebsd )
{
    struct iovec
    {
        void*  iov_base;
        size_t iov_len;
    }

    ssize_t readv(int, in iovec*, int);
    ssize_t writev(int, in iovec*, int);
}
