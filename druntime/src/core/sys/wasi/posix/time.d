module core.sys.wasi.posix.time;

import core.stdc.config : muslRedirTime64Mangle;
import core.sys.wasi.posix.stdc.time : time_t;

extern(C):
@nogc:
nothrow:
@trusted:

struct __clockid;
alias clockid_t = __clockid*;

private extern __gshared __clockid _CLOCK_MONOTONIC;
enum CLOCK_MONOTONIC = &_CLOCK_MONOTONIC;
private extern __gshared __clockid _CLOCK_REALTIME;
enum CLOCK_REALTIME = &_CLOCK_REALTIME;

struct timespec {
  time_t tv_sec;
  long tv_nsec;
}

alias long suseconds_t;

struct timeval
{
    time_t      tv_sec;
    suseconds_t tv_usec;
}

// No need for muslRedirTime64Mangle (even though WASI-libc is a musl fork)
// since _REDIR_TIME64 will never be set for Wasm (even wasm32)
int clock_getres(clockid_t, timespec*);
int clock_gettime(clockid_t, timespec*);

int nanosleep(const scope timespec*, timespec*);
