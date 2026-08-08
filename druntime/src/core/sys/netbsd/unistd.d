//Written in the D programming language

/++
    D header file for NetBSD's extensions to POSIX's unistd.h.

    Copyright: Copyright 2018
    License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   $(HTTP jmdavisprog.com, Jonathan M Davis)
 +/
module core.sys.netbsd.unistd;

public import core.sys.posix.unistd;

version (NetBSD):
extern(C):
@nogc:
nothrow:

void closefrom(int);
