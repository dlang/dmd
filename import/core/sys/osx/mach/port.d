/**
 * D header file for OSX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 */
module core.sys.osx.mach.port;

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
