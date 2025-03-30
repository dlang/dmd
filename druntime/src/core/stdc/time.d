/**
 * D header file for C99.
 *
 * $(C_HEADER_DESCRIPTION pubs.opengroup.org/onlinepubs/009695399/basedefs/_time.h.html, _time.h)
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly,
 *            Alex Rønne Petersen
 * Source:    $(DRUNTIMESRC core/stdc/_time.d)
 * Standards: ISO/IEC 9899:1999 (E)
 */

module core.stdc.time;

version (Posix)
    public import core.sys.posix.stdc.time;
else version (Windows)
    public import core.sys.windows.stdc.time;
else
    static assert(0, "unsupported system");

import core.stdc.config;

extern (C):
@trusted: // There are only a few functions here that use unsafe C strings.
nothrow:
@nogc:

///
pragma(mangle, muslRedirTime64Mangle!("difftime", "__difftime64"))
pure double  difftime(time_t time1, time_t time0); // MT-Safe
///
pragma(mangle, muslRedirTime64Mangle!("mktime", "__mktime64"))
@system time_t  mktime(scope tm* timeptr); // @system: MT-Safe env locale
///
pragma(mangle, muslRedirTime64Mangle!("time", "__time64"))
time_t  time(scope time_t* timer);

///
@system char*   asctime(const scope tm* timeptr); // @system: MT-Unsafe race:asctime locale
///
pragma(mangle, muslRedirTime64Mangle!("ctime", "__ctime64"))
@system char*   ctime(const scope time_t* timer); // @system: MT-Unsafe race:tmbuf race:asctime env locale
///
pragma(mangle, muslRedirTime64Mangle!("gmtime", "__gmtime64"))
@system tm*     gmtime(const scope time_t* timer); // @system: MT-Unsafe race:tmbuf env locale
///
pragma(mangle, muslRedirTime64Mangle!("localtime", "__localtime64"))
@system tm*     localtime(const scope time_t* timer); // @system: MT-Unsafe race:tmbuf env locale
///
@system size_t  strftime(scope char* s, size_t maxsize, const scope char* format, const scope tm* timeptr); // @system: MT-Safe env locale
