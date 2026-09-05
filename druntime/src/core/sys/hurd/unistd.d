/**
 * D header file for GNU/Hurd.
 *
 * Copyright: Copyright (c) 2026 D Language Foundation
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 */
module core.sys.hurd.unistd;

public import core.sys.posix.unistd;

version (Hurd):
extern(C):
nothrow:
@nogc:


// Additional seek constants for sparse file handling
// from Hurds's unistd.h, stdio.h
enum {
    /// Offset is relative to the next location containing data
    SEEK_DATA = 3,
    /// Offset is relative to the next hole (or EOF if file is not sparse)
    SEEK_HOLE = 4
}

/// Prompt for a password without echoing it.
char* getpass(const(char)* prompt);

/// Close all open file descriptors greater or equal to `lowfd`
void closefrom(int lowfd);
