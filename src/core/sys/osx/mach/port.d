/**
 * D header file for OSX.
 *
 * Copyright: Copyright Sean Kelly 2008 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 */

/*          Copyright Sean Kelly 2008 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.osx.mach.port;

version (OSX):

extern (C):

version( X86 )
    version = i386;
version( X86_64 )
    version = i386;
version( i386 )
{
    alias uint        natural_t;
    alias natural_t   mach_port_t;
}
