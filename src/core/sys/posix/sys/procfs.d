/**
 * D header file for POSIX.
 *
 * Copyright: Teodor Dutu 2021.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Teodor Dutu
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

module core.sys.posix.sys.procfs;

import core.sys.posix.sys.types : pid_t;

version (linux)
{
    alias lwpid_t = pid_t;
}
