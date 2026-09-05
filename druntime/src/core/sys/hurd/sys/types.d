/**
 * D header file for Hurd extensions to POSIX's sys/types.h.
 *
 * Copyright: Copyright (c) 2026 D Language Foundation
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */

module core.sys.hurd.sys.types;

import core.sys.posix.config;

version (Hurd):
extern(C):
@nogc:
nothrow:

static if (__WORDSIZE == 32)
    alias ipc_pid_t = ushort;
else
    alias ipc_pid_t = int;

alias fsid_t = ulong;
