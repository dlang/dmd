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
else version( OSX )
{
    struct utimbuf
    {
        time_t  actime;
        time_t  modtime;
    }

    int utime(in char*, in utimbuf*);
}
else version( FreeBSD )
{
    struct utimbuf
    {
        time_t  actime;
        time_t  modtime;
    }

    int utime(in char*, in utimbuf*);
}
