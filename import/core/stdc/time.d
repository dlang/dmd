/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module core.stdc.time;

private import core.stdc.config;
private import core.stdc.stddef;

extern (C):

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
    clock_t CLOCKS_PER_SEC = 1000;
}
else version( OSX )
{
    clock_t CLOCKS_PER_SEC = 100;
}
else version( freebsd )
{
    clock_t CLOCKS_PER_SEC = 128;
}
else
{
    clock_t CLOCKS_PER_SEC = 1000000;
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
size_t  wcsftime(wchar_t* s, size_t maxsize, in wchar_t* format, in tm* timeptr);

version( Windows )
{
    void  tzset();
    void  _tzset();
    char* _strdate(char* s);
    char* _strtime(char* s);

    wchar_t* _wasctime(tm*);
    wchar_t* _wctime(time_t*);
    wchar_t* _wstrdate(wchar_t*);
    wchar_t* _wstrtime(wchar_t*);
}
else version( linux )
{
    void tzset();
}
else version( freebsd )
{
    void tzset();
}
