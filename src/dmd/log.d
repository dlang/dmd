/**
This module defines symbols to support the recommended debug logging pattern for dmd.

Example:
---
import dmd.log;

void foo(int x)
{
    logf("foo was called with x = %d\n", x);

    if (logEnabled)
    {
        // do some setup for the log message
        logf(...);
    }

    // Use this if you want to log a message even when logging is not enabled.
    forcelogf(...);
}
---
*/
module dmd.log;

/** The global log switch. Affects all calls to `logf`. */
private enum allLoggingEnabled = false;

/**
Call to see if logging is enabled for a particular module.
*/
bool logEnabled(string mod = __MODULE__)
{
    return false
        // || mod == "dmd.access"
        // || mod == "dmd.aggregate"
        // || mod == "dmd.apply"
        ;
}

// mark as pure/trusted so that logging can be done in pure/safe functions
private extern (C) int printf(const(char)* format, ...) pure @trusted;

/**
Log if `logEnabled` is `true`.
*/
void logf(string mod = __MODULE__, T...)(string format, T args) pure @trusted
{
    static if (allLoggingEnabled || logEnabled(mod))
    {
        printf(format.ptr, args);
    }
}

/**
Forecefully log a message even if logging is not enabled.
*/
void forcelogf(T...)(string format, T args) pure @trusted
{
    printf(format, args);
}
