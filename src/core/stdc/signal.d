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
module core.stdc.signal;

extern (C):

// this should be volatile
alias int sig_atomic_t;

private alias void function(int) sigfn_t;

version( Posix )
{
    enum SIG_ERR    = cast(sigfn_t) -1;
    enum SIG_DFL    = cast(sigfn_t) 0;
    enum SIG_IGN    = cast(sigfn_t) 1;

    // standard C signals
    enum SIGABRT    = 6;  // Abnormal termination
    enum SIGFPE     = 8;  // Floating-point error
    enum SIGILL     = 4;  // Illegal hardware instruction
    enum SIGINT     = 2;  // Terminal interrupt character
    enum SIGSEGV    = 11; // Invalid memory reference
    enum SIGTERM    = 15; // Termination
}
else
{
    enum SIG_ERR    = cast(sigfn_t) -1;
    enum SIG_DFL    = cast(sigfn_t) 0;
    enum SIG_IGN    = cast(sigfn_t) 1;

    // standard C signals
    enum SIGABRT    = 22; // Abnormal termination
    enum SIGFPE     = 8;  // Floating-point error
    enum SIGILL     = 4;  // Illegal hardware instruction
    enum SIGINT     = 2;  // Terminal interrupt character
    enum SIGSEGV    = 11; // Invalid memory reference
    enum SIGTERM    = 15; // Termination
}

sigfn_t signal(int sig, sigfn_t func);
int     raise(int sig);
