/**
 * D header file for C99.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.stdc.time;

private import core.stdc.config;
private import core.stdc.stddef; // for size_t

extern (C):

nothrow:

version( Windows )
{
    struct tm
    {
        int     tm_sec;     // seconds after the minute - [0, 60]
        int     tm_min;     // minutes after the hour - [0, 59]
        int     tm_hour;    // hours since midnight - [0, 23]
        int     tm_mday;    // day of the month - [1, 31]
        int     tm_mon;     // months since January - [0, 11]
        int     tm_year;    // years since 1900
        int     tm_wday;    // days since Sunday - [0, 6]
        int     tm_yday;    // days since January 1 - [0, 365]
        int     tm_isdst;   // Daylight Saving Time flag
    }
}
else
{
    struct tm
    {
        int     tm_sec;     // seconds after the minute [0-60]
        int     tm_min;     // minutes after the hour [0-59]
        int     tm_hour;    // hours since midnight [0-23]
        int     tm_mday;    // day of the month [1-31]
        int     tm_mon;     // months since January [0-11]
        int     tm_year;    // years since 1900
        int     tm_wday;    // days since Sunday [0-6]
        int     tm_yday;    // days since January 1 [0-365]
        int     tm_isdst;   // Daylight Savings Time flag
        c_long  tm_gmtoff;  // offset from CUT in seconds
        char*   tm_zone;    // timezone abbreviation
    }
}

alias c_long time_t;
alias c_long clock_t;

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
    enum clock_t CLOCKS_PER_SEC = 1000000;
}

clock_t clock();
double  difftime(time_t time1, time_t time0);
time_t  mktime(tm* timeptr);
time_t  time(time_t* timer);
char*   asctime(in tm* timeptr);
char*   ctime(in time_t* timer);
tm*     gmtime(in time_t* timer);
tm*     localtime(in time_t* timer);
size_t  strftime(char* s, size_t maxsize, in char* format, in tm* timeptr);

version( Windows )
{
    void  tzset();                           // non-standard
    void  _tzset();                          // non-standard
    char* _strdate(char* s);                 // non-standard
    char* _strtime(char* s);                 // non-standard
    
    extern __gshared const(char)*[2] tzname; // non-standard
}
else version( OSX )
{
    void tzset();                            // non-standard
    extern __gshared const(char)*[2] tzname; // non-standard
}
else version( linux )
{
    void tzset();                            // non-standard
    extern __gshared const(char)*[2] tzname; // non-standard
}
else version( FreeBSD )
{
    void tzset();                            // non-standard
    extern __gshared const(char)*[2] tzname; // non-standard
}
