/**
 * D header file for GNU/Hurd.
 *
 * Copyright: Copyright (c) 2026 D Language Foundation
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module core.sys.hurd.execinfo;

version (Hurd):
extern (C):
nothrow:
@nogc:

int backtrace(void** buffer, int size);
char** backtrace_symbols(const(void*)* buffer, int size);
void backtrace_symbols_fd(const(void*)* buffer, int size, int fd);
