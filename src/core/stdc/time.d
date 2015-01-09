/**
 * D header file for C99.
 *
 * $(C_HEADER_DESCRIPTION pubs.opengroup.org/onlinepubs/009695399/basedefs/time.h.html, time.h)
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

private import core.stdc.config;
private import core.stdc.stddef; // for size_t

extern (C):
@trusted: // There are only a few functions here that use unsafe C strings.
nothrow:
@nogc:

version( Windows )
{
    ///
    struct tm
    {
        int     tm_sec;     /// seconds after the minute - [0, 60]
        int     tm_min;     /// minutes after the hour - [0, 59]
        int     tm_hour;    /// hours since midnight - [0, 23]
        int     tm_mday;    /// day of the month - [1, 31]
        int     tm_mon;     /// months since January - [0, 11]
        int     tm_year;    /// years since 1900
        int     tm_wday;    /// days since Sunday - [0, 6]
        int     tm_yday;    /// days since January 1 - [0, 365]
        int     tm_isdst;   /// Daylight Saving Time flag
    }
}
else
{
    ///
    struct tm
    {
        int     tm_sec;     /// seconds after the minute [0-60]
        int     tm_min;     /// minutes after the hour [0-59]
        int     tm_hour;    /// hours since midnight [0-23]
        int     tm_mday;    /// day of the month [1-31]
        int     tm_mon;     /// months since January [0-11]
        int     tm_year;    /// years since 1900
        int     tm_wday;    /// days since Sunday [0-6]
        int     tm_yday;    /// days since January 1 [0-365]
        int     tm_isdst;   /// Daylight Savings Time flag
        c_long  tm_gmtoff;  /// offset from CUT in seconds
        char*   tm_zone;    /// timezone abbreviation
    }
}

version ( Posix )
{
    public import core.sys.posix.sys.types : time_t, clock_t;
}
else
{
    ///
    alias c_long time_t;
    ///
    alias c_long clock_t;
}

///
version( Windows )
{
    enum clock_t CLOCKS_PER_SEC = 1000;
}
else version( OSX )
{
    enum clock_t CLOCKS_PER_SEC = 100;
}
else version( FreeBSD )
{
    enum clock_t CLOCKS_PER_SEC = 128;
}
else version (linux)
{
    enum clock_t CLOCKS_PER_SEC = 1_000_000;
}
else version (Android)
{
    enum clock_t CLOCKS_PER_SEC = 1_000_000;
}

///
clock_t clock();
///
double  difftime(time_t time1, time_t time0);
///
time_t  mktime(tm* timeptr);
///
time_t  time(time_t* timer);
///
char*   asctime(in tm* timeptr);
///
char*   ctime(in time_t* timer);
///
tm*     gmtime(in time_t* timer);
///
tm*     localtime(in time_t* timer);
///
@system size_t  strftime(char* s, size_t maxsize, in char* format, in tm* timeptr);

version( Windows )
{
    ///
    void  tzset();                           // non-standard
    ///
    void  _tzset();                          // non-standard
    ///
    @system char* _strdate(char* s);                 // non-standard
    ///
    @system char* _strtime(char* s);                 // non-standard

    ///
    extern __gshared const(char)*[2] tzname; // non-standard
}
else version( OSX )
{
    ///
    void tzset();                            // non-standard
    ///
    extern __gshared const(char)*[2] tzname; // non-standard
}
else version( linux )
{
    ///
    void tzset();                            // non-standard
    ///
    extern __gshared const(char)*[2] tzname; // non-standard
}
else version( FreeBSD )
{
    ///
    void tzset();                            // non-standard
    ///
    extern __gshared const(char)*[2] tzname; // non-standard
}
else version (Solaris)
{
    ///
    void tzset();
    ///
    extern __gshared const(char)*[2] tzname;
}
else version( Android )
{
    ///
    void tzset();
    ///
    extern __gshared const(char)*[2] tzname;
}
else
{
    static assert(false, "Unsupported platform");
}
