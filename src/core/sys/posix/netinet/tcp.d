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
module core.sys.posix.netinet.tcp;

private import core.sys.posix.config;

extern (C):

//
// Required
//
/*
TCP_NODELAY
*/

version( linux )
{
    enum TCP_NODELAY = 1;
}
else version( OSX )
{
    enum TCP_NODELAY = 1;
}
else version( FreeBSD )
{
    enum TCP_NODELAY = 1;
}
