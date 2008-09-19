/**
 * D header file for C99.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 */
module stdc.signal;

extern (C):

// this should be volatile
alias int sig_atomic_t;

private alias void function(int) sigfn_t;

version( Posix )
{
    const SIG_ERR   = cast(sigfn_t) -1;
    const SIG_DFL   = cast(sigfn_t) 0;
    const SIG_IGN   = cast(sigfn_t) 1;

    // standard C signals
    const SIGABRT   = 6;  // Abnormal termination
    const SIGFPE    = 8;  // Floating-point error
    const SIGILL    = 4;  // Illegal hardware instruction
    const SIGINT    = 2;  // Terminal interrupt character
    const SIGSEGV   = 11; // Invalid memory reference
    const SIGTERM   = 15; // Termination
}
else
{
    const SIG_ERR   = cast(sigfn_t) -1;
    const SIG_DFL   = cast(sigfn_t) 0;
    const SIG_IGN   = cast(sigfn_t) 1;

    // standard C signals
    const SIGABRT   = 22; // Abnormal termination
    const SIGFPE    = 8;  // Floating-point error
    const SIGILL    = 4;  // Illegal hardware instruction
    const SIGINT    = 2;  // Terminal interrupt character
    const SIGSEGV   = 11; // Invalid memory reference
    const SIGTERM   = 15; // Termination
}

sigfn_t signal(int sig, sigfn_t func);
int     raise(int sig);
