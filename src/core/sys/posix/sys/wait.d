/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.sys.wait;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for id_t, pid_t
public import core.sys.posix.signal;    // for siginfo_t (XSI)
//public import core.sys.posix.resource; // for rusage (XSI)

extern (C):

//
// Required
//
/*
WNOHANG
WUNTRACED

WEXITSTATUS
WIFCONTINUED
WIFEXITED
WIFSIGNALED
WIFSTOPPED
WSTOPSIG
WTERMSIG

pid_t wait(int*);
pid_t waitpid(pid_t, int*, int);
*/

version( linux )
{
    enum WNOHANG        = 1;
    enum WUNTRACED      = 2;

    private
    {
        enum __W_CONTINUED = 0xFFFF;

        extern (D) int __WTERMSIG( int status ) { return status & 0x7F; }
    }

    //
    // NOTE: These macros assume __USE_BSD is not defined in the relevant
    //       C headers as the parameter definition there is different and
    //       much more complicated.
    //
    extern (D) int  WEXITSTATUS( int status )  { return ( status & 0xFF00 ) >> 8;   }
    extern (D) int  WIFCONTINUED( int status ) { return status == __W_CONTINUED;    }
    extern (D) bool WIFEXITED( int status )    { return __WTERMSIG( status ) == 0;  }
    extern (D) bool WIFSIGNALED( int status )
    {
        return ( cast(byte) ( ( status & 0x7F ) + 1 ) >> 1 ) > 0;
    }
    extern (D) bool WIFSTOPPED( int status )   { return ( status & 0xFF ) == 0x7F;  }
    extern (D) int  WSTOPSIG( int status )     { return WEXITSTATUS( status );      }
    extern (D) int  WTERMSIG( int status )     { return status & 0x7F;              }
}
else version( OSX )
{
    enum WNOHANG        = 1;
    enum WUNTRACED      = 2;

    private
    {
        enum _WSTOPPED = 0177;
    }

    extern (D) int _WSTATUS(int status)         { return (status & 0177);           }
    extern (D) int  WEXITSTATUS( int status )   { return (status >> 8);             }
    extern (D) int  WIFCONTINUED( int status )  { return status == 0x13;            }
    extern (D) bool WIFEXITED( int status )     { return _WSTATUS(status) == 0;     }
    extern (D) bool WIFSIGNALED( int status )
    {
        return _WSTATUS( status ) != _WSTOPPED && _WSTATUS( status ) != 0;
    }
    extern (D) bool WIFSTOPPED( int status )   { return _WSTATUS( status ) == _WSTOPPED; }
    extern (D) int  WSTOPSIG( int status )     { return status >> 8;                     }
    extern (D) int  WTERMSIG( int status )     { return _WSTATUS( status );              }
}
else version( FreeBSD )
{
    enum WNOHANG        = 1;
    enum WUNTRACED      = 2;

    private
    {
        enum _WSTOPPED = 0177;
    }

    extern (D) int _WSTATUS(int status)         { return (status & 0177);           }
    extern (D) int  WEXITSTATUS( int status )   { return (status >> 8);             }
    extern (D) int  WIFCONTINUED( int status )  { return status == 0x13;            }
    extern (D) bool WIFEXITED( int status )     { return _WSTATUS(status) == 0;     }
    extern (D) bool WIFSIGNALED( int status )
    {
        return _WSTATUS( status ) != _WSTOPPED && _WSTATUS( status ) != 0;
    }
    extern (D) bool WIFSTOPPED( int status )   { return _WSTATUS( status ) == _WSTOPPED; }
    extern (D) int  WSTOPSIG( int status )     { return status >> 8;                     }
    extern (D) int  WTERMSIG( int status )     { return _WSTATUS( status );              }
}

version( Posix )
{
    pid_t wait(int*);
    pid_t waitpid(pid_t, int*, int);
}

//
// XOpen (XSI)
//
/*
WEXITED
WSTOPPED
WCONTINUED
WNOWAIT

enum idtype_t
{
    P_ALL,
    P_PID,
    P_PGID
}

int waitid(idtype_t, id_t, siginfo_t*, int);
*/

version( linux )
{
    enum WEXITED    = 4;
    enum WSTOPPED   = 2;
    enum WCONTINUED = 8;
    enum WNOWAIT    = 0x01000000;

    enum idtype_t
    {
        P_ALL,
        P_PID,
        P_PGID
    }

    int waitid(idtype_t, id_t, siginfo_t*, int);
}
else version( OSX )
{
    enum WEXITED    = 0x00000004;
    enum WSTOPPED   = 0x00000008;
    enum WCONTINUED = 0x00000010;
    enum WNOWAIT    = 0x00000020;

    enum idtype_t
    {
        P_ALL,
        P_PID,
        P_PGID
    }

    int waitid(idtype_t, id_t, siginfo_t*, int);
}
else version (FreeBSD)
{
    enum WSTOPPED       = WUNTRACED;
    enum WCONTINUED     = 4;
    enum WNOWAIT        = 8;

    // http://www.freebsd.org/projects/c99/
}

