//Written in the D programming language

/++
    D header file for Hurd extensions to POSIX's time.h.

 +/
module core.sys.hurd.time;

public import core.sys.posix.time;

version (Hurd):

enum CLOCK_MONOTONIC_RAW      = 4;
enum CLOCK_REALTIME_COARSE    = 5;
enum CLOCK_MONOTONIC_COARSE   = 6;;
