/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly, Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.sys.socket;

private import core.sys.posix.config;
public import core.sys.posix.sys.types; // for ssize_t
public import core.sys.posix.sys.uio;   // for iovec

version (Posix):
extern (C) nothrow @nogc:

//
// Required
//
/*
socklen_t
sa_family_t

struct sockaddr
{
    sa_family_t sa_family;
    char        sa_data[];
}

struct sockaddr_storage
{
    sa_family_t ss_family;
}

struct msghdr
{
    void*         msg_name;
    socklen_t     msg_namelen;
    struct iovec* msg_iov;
    int           msg_iovlen;
    void*         msg_control;
    socklen_t     msg_controllen;
    int           msg_flags;
}

struct iovec {} // from core.sys.posix.sys.uio

struct cmsghdr
{
    socklen_t cmsg_len;
    int       cmsg_level;
    int       cmsg_type;
}

SCM_RIGHTS

CMSG_DATA(cmsg)
CMSG_NXTHDR(mhdr,cmsg)
CMSG_FIRSTHDR(mhdr)

struct linger
{
    int l_onoff;
    int l_linger;
}

SOCK_DGRAM
SOCK_SEQPACKET
SOCK_STREAM

SOL_SOCKET

SO_ACCEPTCONN
SO_BROADCAST
SO_DEBUG
SO_DONTROUTE
SO_ERROR
SO_KEEPALIVE
SO_LINGER
SO_OOBINLINE
SO_RCVBUF
SO_RCVLOWAT
SO_RCVTIMEO
SO_REUSEADDR
SO_SNDBUF
SO_SNDLOWAT
SO_SNDTIMEO
SO_TYPE

SOMAXCONN

MSG_CTRUNC
MSG_DONTROUTE
MSG_EOR
MSG_OOB
MSG_PEEK
MSG_TRUNC
MSG_WAITALL

AF_INET
AF_UNIX
AF_UNSPEC

SHUT_RD
SHUT_RDWR
SHUT_WR

int     accept(int, sockaddr*, socklen_t*);
int     bind(int, in sockaddr*, socklen_t);
int     connect(int, in sockaddr*, socklen_t);
int     getpeername(int, sockaddr*, socklen_t*);
int     getsockname(int, sockaddr*, socklen_t*);
int     getsockopt(int, int, int, void*, socklen_t*);
int     listen(int, int);
ssize_t recv(int, void*, size_t, int);
ssize_t recvfrom(int, void*, size_t, int, sockaddr*, socklen_t*);
ssize_t recvmsg(int, msghdr*, int);
ssize_t send(int, in void*, size_t, int);
ssize_t sendmsg(int, in msghdr*, int);
ssize_t sendto(int, in void*, size_t, int, in sockaddr*, socklen_t);
int     setsockopt(int, int, int, in void*, socklen_t);
int     shutdown(int, int);
int     socket(int, int, int);
int     sockatmark(int);
int     socketpair(int, int, int, ref int[2]);
*/

version( CRuntime_Glibc )
{
    // Some of the constants below and from the Bionic section are really from
    // the linux kernel headers.
    alias uint   socklen_t;
    alias ushort sa_family_t;

    struct sockaddr
    {
        sa_family_t sa_family;
        byte[14]    sa_data;
    }

    private enum : size_t
    {
        _SS_SIZE    = 128,
        _SS_PADSIZE = _SS_SIZE - (c_ulong.sizeof * 2)
    }

    struct sockaddr_storage
    {
        sa_family_t ss_family;
        c_ulong     __ss_align;
        byte[_SS_PADSIZE] __ss_padding;
    }

    struct msghdr
    {
        void*     msg_name;
        socklen_t msg_namelen;
        iovec*    msg_iov;
        size_t    msg_iovlen;
        void*     msg_control;
        size_t    msg_controllen;
        int       msg_flags;
    }

    struct cmsghdr
    {
        size_t cmsg_len;
        int    cmsg_level;
        int    cmsg_type;
        static if( false /* (!is( __STRICT_ANSI__ ) && __GNUC__ >= 2) || __STDC_VERSION__ >= 199901L */ )
        {
            ubyte[1] __cmsg_data;
        }
    }

    enum : uint
    {
        SCM_RIGHTS = 0x01
    }

    static if( false /* (!is( __STRICT_ANSI__ ) && __GNUC__ >= 2) || __STDC_VERSION__ >= 199901L */ )
    {
        extern (D) ubyte[1] CMSG_DATA( cmsghdr* cmsg ) pure nothrow @nogc { return cmsg.__cmsg_data; }
    }
    else
    {
        extern (D) inout(ubyte)*   CMSG_DATA( inout(cmsghdr)* cmsg ) pure nothrow @nogc { return cast(ubyte*)( cmsg + 1 ); }
    }

    private inout(cmsghdr)* __cmsg_nxthdr(inout(msghdr)*, inout(cmsghdr)*) pure nothrow @nogc;
    extern (D)  inout(cmsghdr)* CMSG_NXTHDR(inout(msghdr)* msg, inout(cmsghdr)* cmsg) pure nothrow @nogc
    {
        return __cmsg_nxthdr(msg, cmsg);
    }

    extern (D) inout(cmsghdr)* CMSG_FIRSTHDR( inout(msghdr)* mhdr ) pure nothrow @nogc
    {
        return ( cast(size_t)mhdr.msg_controllen >= cmsghdr.sizeof
                             ? cast(inout(cmsghdr)*) mhdr.msg_control
                             : cast(inout(cmsghdr)*) null );
    }

    extern (D)
    {
        size_t CMSG_ALIGN( size_t len ) pure nothrow @nogc
        {
            return (len + size_t.sizeof - 1) & cast(size_t) (~(size_t.sizeof - 1));
        }

        size_t CMSG_LEN( size_t len ) pure nothrow @nogc
        {
            return CMSG_ALIGN(cmsghdr.sizeof) + len;
        }
    }

    extern (D) size_t CMSG_SPACE(size_t len) pure nothrow @nogc
    {
        return CMSG_ALIGN(len) + CMSG_ALIGN(cmsghdr.sizeof);
    }

    struct linger
    {
        int l_onoff;
        int l_linger;
    }

    version (X86)
    {
        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }
    }
    else version (X86_64)
    {
        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }
    }
    else version (MIPS32)
    {
        enum
        {
            SOCK_DGRAM      = 1,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 2,
        }

        enum
        {
            SOL_SOCKET      = 0xffff
        }

        enum
        {
            SO_ACCEPTCONN   = 0x1009,
            SO_BROADCAST    = 0x0020,
            SO_DEBUG        = 0x0001,
            SO_DONTROUTE    = 0x0010,
            SO_ERROR        = 0x1007,
            SO_KEEPALIVE    = 0x0008,
            SO_LINGER       = 0x0080,
            SO_OOBINLINE    = 0x0100,
            SO_RCVBUF       = 0x1002,
            SO_RCVLOWAT     = 0x1004,
            SO_RCVTIMEO     = 0x1006,
            SO_REUSEADDR    = 0x0004,
            SO_SNDBUF       = 0x1001,
            SO_SNDLOWAT     = 0x1003,
            SO_SNDTIMEO     = 0x1005,
            SO_TYPE         = 0x1008,
        }
    }
    else version (MIPS64)
    {
        enum
        {
            SOCK_DGRAM      = 1,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 2,
        }

        enum
        {
            SOL_SOCKET      = 0xffff
        }

        enum
        {
            SO_ACCEPTCONN   = 0x1009,
            SO_BROADCAST    = 0x0020,
            SO_DEBUG        = 0x0001,
            SO_DONTROUTE    = 0x0010,
            SO_ERROR        = 0x1007,
            SO_KEEPALIVE    = 0x0008,
            SO_LINGER       = 0x0080,
            SO_OOBINLINE    = 0x0100,
            SO_RCVBUF       = 0x1002,
            SO_RCVLOWAT     = 0x1004,
            SO_RCVTIMEO     = 0x1006,
            SO_REUSEADDR    = 0x0004,
            SO_SNDBUF       = 0x1001,
            SO_SNDLOWAT     = 0x1003,
            SO_SNDTIMEO     = 0x1005,
            SO_TYPE         = 0x1008,
        }
    }
    else version (PPC)
    {
        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 16,
            SO_RCVTIMEO     = 18,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 17,
            SO_SNDTIMEO     = 19,
            SO_TYPE         = 3
        }
    }
    else version (PPC64)
    {
        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 16,
            SO_RCVTIMEO     = 18,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 17,
            SO_SNDTIMEO     = 19,
            SO_TYPE         = 3
        }
    }
    else version (AArch64)
    {
        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }
    }
    else version (ARM)
    {
        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }
    }
    else
        static assert(0, "unimplemented");

    enum
    {
        SOMAXCONN       = 128
    }

    enum : uint
    {
        MSG_CTRUNC      = 0x08,
        MSG_DONTROUTE   = 0x04,
        MSG_EOR         = 0x80,
        MSG_OOB         = 0x01,
        MSG_PEEK        = 0x02,
        MSG_TRUNC       = 0x20,
        MSG_WAITALL     = 0x100,
        MSG_NOSIGNAL    = 0x4000
    }

    enum
    {
        AF_APPLETALK    = 5,
        AF_INET         = 2,
        AF_IPX          = 4,
        AF_UNIX         = 1,
        AF_UNSPEC       = 0,
        PF_APPLETALK    = AF_APPLETALK,
        PF_IPX          = AF_IPX
    }

    enum int SOCK_RDM   = 4;

    enum
    {
        SHUT_RD,
        SHUT_WR,
        SHUT_RDWR
    }

    int     accept(int, sockaddr*, socklen_t*);
    int     bind(int, in sockaddr*, socklen_t);
    int     connect(int, in sockaddr*, socklen_t);
    int     getpeername(int, sockaddr*, socklen_t*);
    int     getsockname(int, sockaddr*, socklen_t*);
    int     getsockopt(int, int, int, void*, socklen_t*);
    int     listen(int, int);
    ssize_t recv(int, void*, size_t, int);
    ssize_t recvfrom(int, void*, size_t, int, sockaddr*, socklen_t*);
    ssize_t recvmsg(int, msghdr*, int);
    ssize_t send(int, in void*, size_t, int);
    ssize_t sendmsg(int, in msghdr*, int);
    ssize_t sendto(int, in void*, size_t, int, in sockaddr*, socklen_t);
    int     setsockopt(int, int, int, in void*, socklen_t);
    int     shutdown(int, int);
    int     socket(int, int, int);
    int     sockatmark(int);
    int     socketpair(int, int, int, ref int[2]);
}
else version( OSX )
{
    alias uint   socklen_t;
    alias ubyte  sa_family_t;

    struct sockaddr
    {
        ubyte       sa_len;
        sa_family_t sa_family;
        byte[14]    sa_data;
    }

    private enum : size_t
    {
        _SS_PAD1    = long.sizeof - ubyte.sizeof - sa_family_t.sizeof,
        _SS_PAD2    = 128 - ubyte.sizeof - sa_family_t.sizeof - _SS_PAD1 - long.sizeof
    }

    struct sockaddr_storage
    {
         ubyte          ss_len;
         sa_family_t    ss_family;
         byte[_SS_PAD1] __ss_pad1;
         long           __ss_align;
         byte[_SS_PAD2] __ss_pad2;
    }

    struct msghdr
    {
        void*     msg_name;
        socklen_t msg_namelen;
        iovec*    msg_iov;
        int       msg_iovlen;
        void*     msg_control;
        socklen_t msg_controllen;
        int       msg_flags;
    }

    struct cmsghdr
    {
         socklen_t cmsg_len;
         int       cmsg_level;
         int       cmsg_type;
    }

    enum : uint
    {
        SCM_RIGHTS = 0x01
    }

    /+
    CMSG_DATA(cmsg)     ((unsigned char *)(cmsg) + \
                         ALIGN(sizeof(struct cmsghdr)))
    CMSG_NXTHDR(mhdr, cmsg) \
                        (((unsigned char *)(cmsg) + ALIGN((cmsg)->cmsg_len) + \
                         ALIGN(sizeof(struct cmsghdr)) > \
                         (unsigned char *)(mhdr)->msg_control +(mhdr)->msg_controllen) ? \
                         (struct cmsghdr *)0 /* NULL */ : \
                         (struct cmsghdr *)((unsigned char *)(cmsg) + ALIGN((cmsg)->cmsg_len)))
    CMSG_FIRSTHDR(mhdr) ((struct cmsghdr *)(mhdr)->msg_control)
    +/

    struct linger
    {
        int l_onoff;
        int l_linger;
    }

    enum
    {
        SOCK_DGRAM      = 2,
        SOCK_RDM        = 4,
        SOCK_SEQPACKET  = 5,
        SOCK_STREAM     = 1
    }

    enum : uint
    {
        SOL_SOCKET      = 0xffff
    }

    enum : uint
    {
        SO_ACCEPTCONN   = 0x0002,
        SO_BROADCAST    = 0x0020,
        SO_DEBUG        = 0x0001,
        SO_DONTROUTE    = 0x0010,
        SO_ERROR        = 0x1007,
        SO_KEEPALIVE    = 0x0008,
        SO_LINGER       = 0x1080,
        SO_NOSIGPIPE    = 0x1022, // non-standard
        SO_OOBINLINE    = 0x0100,
        SO_RCVBUF       = 0x1002,
        SO_RCVLOWAT     = 0x1004,
        SO_RCVTIMEO     = 0x1006,
        SO_REUSEADDR    = 0x0004,
        SO_SNDBUF       = 0x1001,
        SO_SNDLOWAT     = 0x1003,
        SO_SNDTIMEO     = 0x1005,
        SO_TYPE         = 0x1008
    }

    enum
    {
        SOMAXCONN       = 128
    }

    enum : uint
    {
        MSG_CTRUNC      = 0x20,
        MSG_DONTROUTE   = 0x4,
        MSG_EOR         = 0x8,
        MSG_OOB         = 0x1,
        MSG_PEEK        = 0x2,
        MSG_TRUNC       = 0x10,
        MSG_WAITALL     = 0x40
    }

    enum
    {
        AF_APPLETALK    = 16,
        AF_INET         = 2,
        AF_IPX          = 23,
        AF_UNIX         = 1,
        AF_UNSPEC       = 0,
        PF_APPLETALK    = AF_APPLETALK,
        PF_IPX          = AF_IPX
    }

    enum
    {
        SHUT_RD,
        SHUT_WR,
        SHUT_RDWR
    }

    int     accept(int, sockaddr*, socklen_t*);
    int     bind(int, in sockaddr*, socklen_t);
    int     connect(int, in sockaddr*, socklen_t);
    int     getpeername(int, sockaddr*, socklen_t*);
    int     getsockname(int, sockaddr*, socklen_t*);
    int     getsockopt(int, int, int, void*, socklen_t*);
    int     listen(int, int);
    ssize_t recv(int, void*, size_t, int);
    ssize_t recvfrom(int, void*, size_t, int, sockaddr*, socklen_t*);
    ssize_t recvmsg(int, msghdr*, int);
    ssize_t send(int, in void*, size_t, int);
    ssize_t sendmsg(int, in msghdr*, int);
    ssize_t sendto(int, in void*, size_t, int, in sockaddr*, socklen_t);
    int     setsockopt(int, int, int, in void*, socklen_t);
    int     shutdown(int, int);
    int     socket(int, int, int);
    int     sockatmark(int);
    int     socketpair(int, int, int, ref int[2]);
}
else version( FreeBSD )
{
    alias uint   socklen_t;
    alias ubyte  sa_family_t;

    struct sockaddr
    {
        ubyte       sa_len;
        sa_family_t sa_family;
        byte[14]    sa_data;
    }

    private
    {
        enum _SS_ALIGNSIZE  = long.sizeof;
        enum _SS_MAXSIZE    = 128;
        enum _SS_PAD1SIZE   = _SS_ALIGNSIZE - ubyte.sizeof - sa_family_t.sizeof;
        enum _SS_PAD2SIZE   = _SS_MAXSIZE - ubyte.sizeof - sa_family_t.sizeof - _SS_PAD1SIZE - _SS_ALIGNSIZE;
    }

    struct sockaddr_storage
    {
         ubyte              ss_len;
         sa_family_t        ss_family;
         byte[_SS_PAD1SIZE] __ss_pad1;
         long               __ss_align;
         byte[_SS_PAD2SIZE] __ss_pad2;
    }

    struct msghdr
    {
        void*     msg_name;
        socklen_t msg_namelen;
        iovec*    msg_iov;
        int       msg_iovlen;
        void*     msg_control;
        socklen_t msg_controllen;
        int       msg_flags;
    }

    struct cmsghdr
    {
         socklen_t cmsg_len;
         int       cmsg_level;
         int       cmsg_type;
    }

    enum : uint
    {
        SCM_RIGHTS = 0x01
    }

    private // <machine/param.h>
    {
        enum _ALIGNBYTES = /+c_int+/ int.sizeof - 1;
        extern (D) size_t _ALIGN( size_t p ) { return (p + _ALIGNBYTES) & ~_ALIGNBYTES; }
    }

    extern (D) ubyte* CMSG_DATA( cmsghdr* cmsg )
    {
        return cast(ubyte*) cmsg + _ALIGN( cmsghdr.sizeof );
    }

    extern (D) cmsghdr* CMSG_NXTHDR( msghdr* mhdr, cmsghdr* cmsg )
    {
        if( cmsg == null )
        {
           return CMSG_FIRSTHDR( mhdr );
        }
        else
        {
            if( cast(ubyte*) cmsg + _ALIGN( cmsg.cmsg_len ) + _ALIGN( cmsghdr.sizeof ) >
                    cast(ubyte*) mhdr.msg_control + mhdr.msg_controllen )
                return null;
            else
                return cast(cmsghdr*) (cast(ubyte*) cmsg + _ALIGN( cmsg.cmsg_len ));
        }
    }

    extern (D) cmsghdr* CMSG_FIRSTHDR( msghdr* mhdr )
    {
        return mhdr.msg_controllen >= cmsghdr.sizeof ? cast(cmsghdr*) mhdr.msg_control : null;
    }

    struct linger
    {
        int l_onoff;
        int l_linger;
    }

    enum
    {
        SOCK_DGRAM      = 2,
        SOCK_RDM        = 4,
        SOCK_SEQPACKET  = 5,
        SOCK_STREAM     = 1
    }

    enum : uint
    {
        SOL_SOCKET      = 0xffff
    }

    enum : uint
    {
        SO_ACCEPTCONN   = 0x0002,
        SO_BROADCAST    = 0x0020,
        SO_DEBUG        = 0x0001,
        SO_DONTROUTE    = 0x0010,
        SO_ERROR        = 0x1007,
        SO_KEEPALIVE    = 0x0008,
        SO_LINGER       = 0x0080,
        SO_NOSIGPIPE    = 0x0800, // non-standard
        SO_OOBINLINE    = 0x0100,
        SO_RCVBUF       = 0x1002,
        SO_RCVLOWAT     = 0x1004,
        SO_RCVTIMEO     = 0x1006,
        SO_REUSEADDR    = 0x0004,
        SO_SNDBUF       = 0x1001,
        SO_SNDLOWAT     = 0x1003,
        SO_SNDTIMEO     = 0x1005,
        SO_TYPE         = 0x1008
    }

    enum
    {
        SOMAXCONN       = 128
    }

    enum : uint
    {
        MSG_CTRUNC      = 0x20,
        MSG_DONTROUTE   = 0x4,
        MSG_EOR         = 0x8,
        MSG_OOB         = 0x1,
        MSG_PEEK        = 0x2,
        MSG_TRUNC       = 0x10,
        MSG_WAITALL     = 0x40,
        MSG_NOSIGNAL    = 0x20000
    }

    enum
    {
        AF_APPLETALK    = 16,
        AF_INET         = 2,
        AF_IPX          = 23,
        AF_UNIX         = 1,
        AF_UNSPEC       = 0
    }

    enum
    {
        SHUT_RD = 0,
        SHUT_WR = 1,
        SHUT_RDWR = 2
    }

    int     accept(int, sockaddr*, socklen_t*);
    int     bind(int, in sockaddr*, socklen_t);
    int     connect(int, in sockaddr*, socklen_t);
    int     getpeername(int, sockaddr*, socklen_t*);
    int     getsockname(int, sockaddr*, socklen_t*);
    int     getsockopt(int, int, int, void*, socklen_t*);
    int     listen(int, int);
    ssize_t recv(int, void*, size_t, int);
    ssize_t recvfrom(int, void*, size_t, int, sockaddr*, socklen_t*);
    ssize_t recvmsg(int, msghdr*, int);
    ssize_t send(int, in void*, size_t, int);
    ssize_t sendmsg(int, in msghdr*, int);
    ssize_t sendto(int, in void*, size_t, int, in sockaddr*, socklen_t);
    int     setsockopt(int, int, int, in void*, socklen_t);
    int     shutdown(int, int);
    int     socket(int, int, int);
    int     sockatmark(int);
    int     socketpair(int, int, int, ref int[2]);
}
else version (Solaris)
{
    alias uint socklen_t;
    alias ushort sa_family_t;

    struct sockaddr
    {
        sa_family_t sa_family;
        char[14] sa_data;
    }

    alias double sockaddr_maxalign_t;

    private
    {
        enum _SS_ALIGNSIZE  = sockaddr_maxalign_t.sizeof;
        enum _SS_MAXSIZE    = 256;
        enum _SS_PAD1SIZE   = _SS_ALIGNSIZE - sa_family_t.sizeof;
        enum _SS_PAD2SIZE   = _SS_MAXSIZE - sa_family_t.sizeof + _SS_PAD1SIZE + _SS_ALIGNSIZE;
    }

    struct sockaddr_storage
    {
         sa_family_t ss_family;
         char[_SS_PAD1SIZE] _ss_pad1;
         sockaddr_maxalign_t _ss_align;
         char[_SS_PAD2SIZE] _ss_pad2;
    }

    struct msghdr
    {
        void* msg_name;
        socklen_t msg_namelen;
        iovec* msg_iov;
        int msg_iovlen;
        void* msg_control;
        socklen_t msg_controllen;
        int msg_flags;
    }

    struct cmsghdr
    {
         socklen_t cmsg_len;
         int cmsg_level;
         int cmsg_type;
    }

    enum : uint
    {
        SCM_RIGHTS = 0x1010
    }

    // FIXME: CMSG_DATA, CMSG_NXTHDR, CMSG_FIRSTHDR missing

    struct linger
    {
        int l_onoff;
        int l_linger;
    }

    enum
    {
        SOCK_STREAM = 2,
        SOCK_DGRAM = 1,
        SOCK_RDM = 5,
        SOCK_SEQPACKET = 6,
    }

    enum : uint
    {
        SOL_SOCKET      = 0xffff
    }

    enum : uint
    {
        SO_ACCEPTCONN   = 0x0002,
        SO_BROADCAST    = 0x0020,
        SO_DEBUG        = 0x0001,
        SO_DONTROUTE    = 0x0010,
        SO_ERROR        = 0x1007,
        SO_KEEPALIVE    = 0x0008,
        SO_LINGER       = 0x0080,
        SO_OOBINLINE    = 0x0100,
        SO_RCVBUF       = 0x1002,
        SO_RCVLOWAT     = 0x1004,
        SO_RCVTIMEO     = 0x1006,
        SO_REUSEADDR    = 0x0004,
        SO_SNDBUF       = 0x1001,
        SO_SNDLOWAT     = 0x1003,
        SO_SNDTIMEO     = 0x1005,
        SO_TYPE         = 0x1008,

        SO_USELOOPBACK  = 0x0040, // non-standard
        SO_DGRAM_ERRIND = 0x0200, // non-standard
        SO_RECVUCRED    = 0x0400, // non-standard
    }

    enum
    {
        SOMAXCONN = 128
    }

    enum : uint
    {
        MSG_CTRUNC      = 0x10,
        MSG_DONTROUTE   = 0x4,
        MSG_EOR         = 0x8,
        MSG_OOB         = 0x1,
        MSG_PEEK        = 0x2,
        MSG_TRUNC       = 0x20,
        MSG_WAITALL     = 0x40
    }

    enum
    {
        AF_IPX          = 23,
        AF_APPLETALK    = 16,
        AF_INET         = 2,
        AF_UNIX         = 1,
        AF_UNSPEC       = 0
    }

    enum
    {
        SHUT_RD,
        SHUT_WR,
        SHUT_RDWR
    }

    int accept(int, sockaddr*, socklen_t*);
    int bind(int, in sockaddr*, socklen_t);
    int connect(int, in sockaddr*, socklen_t);
    int getpeername(int, sockaddr*, socklen_t*);
    int getsockname(int, sockaddr*, socklen_t*);
    int getsockopt(int, int, int, void*, socklen_t*);
    int listen(int, int);
    ssize_t recv(int, void*, size_t, int);
    ssize_t recvfrom(int, void*, size_t, int, sockaddr*, socklen_t*);
    ssize_t recvmsg(int, msghdr*, int);
    ssize_t send(int, in void*, size_t, int);
    ssize_t sendmsg(int, in msghdr*, int);
    ssize_t sendto(int, in void*, size_t, int, in sockaddr*, socklen_t);
    int setsockopt(int, int, int, in void*, socklen_t);
    int shutdown(int, int);
    int socket(int, int, int);
    int sockatmark(int);
    int socketpair(int, int, int, ref int[2]);
}
else version( CRuntime_Bionic )
{
    alias int    socklen_t;
    alias ushort sa_family_t;

    struct sockaddr
    {
        sa_family_t sa_family;
        byte[14]    sa_data;
    }

    private enum size_t _K_SS_MAXSIZE  = 128;

    struct sockaddr_storage
    {
        ushort ss_family;
        byte[_K_SS_MAXSIZE - ushort.sizeof] __data;
    }

    enum : uint
    {
        SCM_RIGHTS = 0x01
    }

    private enum _ALIGNBYTES = c_long.sizeof - 1;

    extern (D)
    {
        size_t CMSG_ALIGN( size_t len )
        {
            return (len + _ALIGNBYTES) & ~_ALIGNBYTES;
        }

        void* CMSG_DATA( cmsghdr* cmsg )
        {
            return cast(void*) (cast(char*) cmsg + CMSG_ALIGN( cmsghdr.sizeof ));
        }

        cmsghdr* CMSG_NXTHDR( msghdr* mhdr, cmsghdr* cmsg )
        {
            cmsghdr* __ptr = cast(cmsghdr*) ((cast(ubyte*) cmsg) + CMSG_ALIGN(cmsg.cmsg_len));
            return cast(c_ulong)( cast(char*)(__ptr+1) - cast(char*) mhdr.msg_control) > mhdr.msg_controllen ? null : __ptr;
        }

        cmsghdr* CMSG_FIRSTHDR( msghdr* mhdr )
        {
            return mhdr.msg_controllen >= cmsghdr.sizeof ? cast(cmsghdr*) mhdr.msg_control : null;
        }
    }

    struct linger
    {
        int l_onoff;
        int l_linger;
    }

    version (X86)
    {
        struct msghdr
        {
            void*  msg_name;
            int    msg_namelen;
            iovec* msg_iov;
            uint   msg_iovlen;
            void*  msg_control;
            uint   msg_controllen;
            uint   msg_flags;
        }

        struct cmsghdr
        {
            uint cmsg_len;
            int  cmsg_level;
            int  cmsg_type;
        }

        enum
        {
            SOCK_DGRAM      = 2,
            SOCK_SEQPACKET  = 5,
            SOCK_STREAM     = 1
        }

        enum
        {
            SOL_SOCKET      = 1
        }

        enum
        {
            SO_ACCEPTCONN   = 30,
            SO_BROADCAST    = 6,
            SO_DEBUG        = 1,
            SO_DONTROUTE    = 5,
            SO_ERROR        = 4,
            SO_KEEPALIVE    = 9,
            SO_LINGER       = 13,
            SO_OOBINLINE    = 10,
            SO_RCVBUF       = 8,
            SO_RCVLOWAT     = 18,
            SO_RCVTIMEO     = 20,
            SO_REUSEADDR    = 2,
            SO_SNDBUF       = 7,
            SO_SNDLOWAT     = 19,
            SO_SNDTIMEO     = 21,
            SO_TYPE         = 3
        }
    }
    else
    {
        static assert(false, "Architecture not supported.");
    }

    enum
    {
        SOMAXCONN       = 128
    }

    enum : uint
    {
        MSG_CTRUNC      = 0x08,
        MSG_DONTROUTE   = 0x04,
        MSG_EOR         = 0x80,
        MSG_OOB         = 0x01,
        MSG_PEEK        = 0x02,
        MSG_TRUNC       = 0x20,
        MSG_WAITALL     = 0x100
    }

    enum
    {
        AF_APPLETALK    = 5,
        AF_INET         = 2,
        AF_IPX          = 4,
        AF_UNIX         = 1,
        AF_UNSPEC       = 0
    }

    enum
    {
        SHUT_RD,
        SHUT_WR,
        SHUT_RDWR
    }

    enum SOCK_RDM = 4;

    int     accept(int, sockaddr*, socklen_t*);
    int     bind(int, in sockaddr*, int);
    int     connect(int, in sockaddr*, socklen_t);
    int     getpeername(int, sockaddr*, socklen_t*);
    int     getsockname(int, sockaddr*, socklen_t*);
    int     getsockopt(int, int, int, void*, socklen_t*);
    int     listen(int, int);
    ssize_t recv(int, void*, size_t, uint);
    ssize_t recvfrom(int, void*, size_t, uint, in sockaddr*, socklen_t*);
    int     recvmsg(int, msghdr*, uint);
    ssize_t send(int, in void*, size_t, uint);
    int     sendmsg(int, in msghdr*, uint);
    ssize_t sendto(int, in void*, size_t, int, in sockaddr*, socklen_t);
    int     setsockopt(int, int, int, in void*, socklen_t);
    int     shutdown(int, int);
    int     socket(int, int, int);
    int     socketpair(int, int, int, ref int[2]);
}
else
{
    static assert(false, "Unsupported platform");
}

//
// IPV6 (IP6)
//
/*
AF_INET6
*/

version( CRuntime_Glibc )
{
    enum
    {
        AF_INET6    = 10
    }
}
else version( OSX )
{
    enum
    {
        AF_INET6    = 30
    }
}
else version( FreeBSD )
{
    enum
    {
        AF_INET6    = 28
    }
}
else version (Solaris)
{
    enum
    {
        AF_INET6 = 26,
    }
}
else version( CRuntime_Bionic )
{
    enum
    {
        AF_INET6    = 10
    }
}
else
{
    static assert(false, "Unsupported platform");
}

//
// Raw Sockets (RS)
//
/*
SOCK_RAW
*/

version( CRuntime_Glibc )
{
    enum
    {
        SOCK_RAW    = 3
    }
}
else version( OSX )
{
    enum
    {
        SOCK_RAW    = 3
    }
}
else version( FreeBSD )
{
    enum
    {
        SOCK_RAW    = 3
    }
}
else version (Solaris)
{
    enum
    {
        SOCK_RAW = 4,
    }
}
else version( CRuntime_Bionic )
{
    enum
    {
        SOCK_RAW    = 3
    }
}
else
{
    static assert(false, "Unsupported platform");
}
