/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.utime;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for time_t

extern (C):

//
// Required
//
/*
struct utimbuf
{
    time_t  actime;
    time_t  modtime;
}

int utime(in char*, in utimbuf*);
*/

version( linux )
{
    struct utimbuf
    {
        time_t  actime;
        time_t  modtime;
    }

    int utime(in char*, in utimbuf*);
}
else version( darwin )
{
    struct utimbuf
    {
        time_t  actime;
        time_t  modtime;
    }

    int utime(in char*, in utimbuf*);
}
else version( freebsd )
{
    struct utimbuf
    {
        time_t  actime;
        time_t  modtime;
    }

    int utime(in char*, in utimbuf*);
}
