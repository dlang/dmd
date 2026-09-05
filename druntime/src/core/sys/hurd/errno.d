/**
 * D header file for GNU/Hurd
 *
 * Copyright: Copyright (c) 2026 D Language Foundation
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * $(LINK2 http://sourceware.org/git/?p=glibc.git;a=blob;f=stdlib/errno.h, glibc stdlib/errno.h)
 */
module core.sys.hurd.errno;

version (Hurd):
extern (C):
nothrow:

public import core.stdc.errno;
import core.sys.hurd.config;

static if (_GNU_SOURCE)
{
    extern __gshared char* program_invocation_name, program_invocation_short_name;
    alias error_t = int;
}
