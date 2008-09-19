/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module stdc.posix.time;

private import stdc.posix.config;
public import stdc.time;
public import stdc.posix.sys.types;
public import stdc.posix.signal; // for sigevent

extern (C):

//
// Required (defined in stdc.time)
//
/*
char* asctime(in tm*);
clock_t clock();
char* ctime(in time_t*);
double difftime(time_t, time_t);
tm* gmtime(in time_t*);
tm* localtime(in time_t*);
time_t mktime(tm*);
size_t strftime(char*, size_t, in char*, in tm*);
time_t time(time_t*);
*/

version( linux )
{
    time_t timegm(tm*); // non-standard
}
else version( darwin )
{
    time_t timegm(tm*); // non-standard
}
else version( freebsd )
{
    time_t timegm(tm*); // non-standard
}

//
// C Extension (CX)
// (defined in stdc.time)
//
/*
char* tzname[];
void tzset();
*/

//
// Process CPU-Time Clocks (CPT)
//
/*
int clock_getcpuclockid(pid_t, clockid_t*);
*/

//
// Clock Selection (CS)
//
/*
int clock_nanosleep(clockid_t, int, in timespec*, timespec*);
*/

//
// Monotonic Clock (MON)
//
/*
CLOCK_MONOTONIC
*/

//
// Timer (TMR)
//
/*
CLOCK_PROCESS_CPUTIME_ID (TMR|CPT)
CLOCK_THREAD_CPUTIME_ID (TMR|TCT)

NOTE: timespec must be defined in stdc.posix.signal to break
      a circular import.

struct timespec
{
    time_t  tv_sec;
    int     tv_nsec;
}

struct itimerspec
{
    timespec it_interval;
    timespec it_value;
}

CLOCK_REALTIME
TIMER_ABSTIME

clockid_t
timer_t

int clock_getres(clockid_t, timespec*);
int clock_gettime(clockid_t, timespec*);
int clock_settime(clockid_t, in timespec*);
int nanosleep(in timespec*, timespec*);
int timer_create(clockid_t, sigevent*, timer_t*);
int timer_delete(timer_t);
int timer_gettime(timer_t, itimerspec*);
int timer_getoverrun(timer_t);
int timer_settime(timer_t, int, in itimerspec*, itimerspec*);
*/

version( linux )
{
    const CLOCK_PROCESS_CPUTIME_ID  = 2; // (TMR|CPT)
    const CLOCK_THREAD_CPUTIME_ID   = 3; // (TMR|TCT)

    // NOTE: See above for why this is commented out.
    //
    //struct timespec
    //{
    //    time_t  tv_sec;
    //    c_long  tv_nsec;
    //}

    struct itimerspec
    {
        timespec it_interval;
        timespec it_value;
    }

    const CLOCK_REALTIME    = 0;
    const TIMER_ABSTIME     = 0x01;

    alias int clockid_t;
    alias int timer_t;

    int clock_getres(clockid_t, timespec*);
    //int clock_gettime(clockid_t, timespec*);
    //int clock_settime(clockid_t, in timespec*);
    int nanosleep(in timespec*, timespec*);
    int timer_create(clockid_t, sigevent*, timer_t*);
    int timer_delete(timer_t);
    int timer_gettime(timer_t, itimerspec*);
    int timer_getoverrun(timer_t);
    int timer_settime(timer_t, int, in itimerspec*, itimerspec*);
}
else version( darwin )
{
    int nanosleep(in timespec*, timespec*);
}
else version( freebsd )
{
    const CLOCK_PROCESS_CPUTIME_ID  = 2; // (TMR|CPT)
    const CLOCK_THREAD_CPUTIME_ID   = 3; // (TMR|TCT)

    // NOTE: See above for why this is commented out.
    //
    //struct timespec
    //{
    //    time_t  tv_sec;
    //    c_long  tv_nsec;
    //}

    struct itimerspec
    {
        timespec it_interval;
        timespec it_value;
    }

    const CLOCK_REALTIME    = 0;
    const TIMER_ABSTIME     = 0x01;

    alias int clockid_t;
    alias int timer_t;

    int clock_getres(clockid_t, timespec*);
    int clock_gettime(clockid_t, timespec*);
    int clock_settime(clockid_t, in timespec*);
    int nanosleep(in timespec*, timespec*);
    int timer_create(clockid_t, sigevent*, timer_t*);
    int timer_delete(timer_t);
    int timer_gettime(timer_t, itimerspec*);
    int timer_getoverrun(timer_t);
    int timer_settime(timer_t, int, in itimerspec*, itimerspec*);
}


//
// Thread-Safe Functions (TSF)
//
/*
char* asctime_r(in tm*, char*);
char* ctime_r(in time_t*, char*);
tm*   gmtime_r(in time_t*, tm*);
tm*   localtime_r(in time_t*, tm*);
*/

version( linux )
{
    char* asctime_r(in tm*, char*);
    char* ctime_r(in time_t*, char*);
    tm*   gmtime_r(in time_t*, tm*);
    tm*   localtime_r(in time_t*, tm*);
}
else version( darwin )
{
    char* asctime_r(in tm*, char*);
    char* ctime_r(in time_t*, char*);
    tm*   gmtime_r(in time_t*, tm*);
    tm*   localtime_r(in time_t*, tm*);
}
else version( freebsd )
{
    char* asctime_r(in tm*, char*);
    char* ctime_r(in time_t*, char*);
    tm*   gmtime_r(in time_t*, tm*);
    tm*   localtime_r(in time_t*, tm*);
}

//
// XOpen (XSI)
//
/*
getdate_err

int daylight;
int timezone;

tm* getdate(in char*);
char* strptime(in char*, in char*, tm*);
*/

version( linux )
{
    extern int      daylight;
    extern c_long   timezone;

    tm*   getdate(in char*);
    char* strptime(in char*, in char*, tm*);
}
else version( darwin )
{
    extern c_long timezone;

    tm*   getdate(in char*);
    char* strptime(in char*, in char*, tm*);
}
else version( freebsd )
{
    //tm*   getdate(in char*);
    char* strptime(in char*, in char*, tm*);
}
