/**
 * D header file for POSIX.
 *
 * Copyright: Public Domain
 * License:   Public Domain
 * Authors:   Sean Kelly
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */
module core.sys.posix.arpa.inet;

private import core.sys.posix.config;
public import core.stdc.inttypes : uint32_t, uint16_t;
public import core.sys.posix.sys.socket : socklen_t;

extern (C):

//
// Required
//
/*
in_port_t // from core.sys.posix.netinet.in_
in_addr_t // from core.sys.posix.netinet.in_

struct in_addr  // from core.sys.posix.netinet.in_
INET_ADDRSTRLEN // from core.sys.posix.netinet.in_

uint32_t // from core.stdc.inttypes
uint16_t // from core.stdc.inttypes

uint32_t htonl(uint32_t);
uint16_t htons(uint16_t);
uint32_t ntohl(uint32_t);
uint16_t ntohs(uint16_t);

in_addr_t inet_addr(in char*);
char*     inet_ntoa(in_addr);
// per spec: const char* inet_ntop(int, const void*, char*, socklen_t);
char*     inet_ntop(int, in void*, char*, socklen_t);
int       inet_pton(int, in char*, void*);
*/

version( linux )
{
    alias uint16_t in_port_t;
    alias uint32_t in_addr_t;

    struct in_addr
    {
        in_addr_t s_addr;
    }

    const INET_ADDRSTRLEN = 16;

    uint32_t htonl(uint32_t);
    uint16_t htons(uint16_t);
    uint32_t ntohl(uint32_t);
    uint16_t ntohs(uint16_t);

    in_addr_t inet_addr(in char*);
    char*     inet_ntoa(in_addr);
    char*     inet_ntop(int, in void*, char*, socklen_t);
    int       inet_pton(int, in char*, void*);
}
else version( darwin )
{
    alias uint16_t in_port_t; // TODO: verify
    alias uint32_t in_addr_t; // TODO: verify

    struct in_addr
    {
        in_addr_t s_addr;
    }

    const INET_ADDRSTRLEN = 16;

    uint32_t htonl(uint32_t);
    uint16_t htons(uint16_t);
    uint32_t ntohl(uint32_t);
    uint16_t ntohs(uint16_t);

    in_addr_t inet_addr(in char*);
    char*     inet_ntoa(in_addr);
    char*     inet_ntop(int, in void*, char*, socklen_t);
    int       inet_pton(int, in char*, void*);
}
else version( freebsd )
{
    alias uint16_t in_port_t; // TODO: verify
    alias uint32_t in_addr_t; // TODO: verify

    struct in_addr
    {
        in_addr_t s_addr;
    }

    const INET_ADDRSTRLEN = 16;

    uint32_t htonl(uint32_t);
    uint16_t htons(uint16_t);
    uint32_t ntohl(uint32_t);
    uint16_t ntohs(uint16_t);

    in_addr_t inet_addr(in char*);
    char*     inet_ntoa(in_addr);
    char*     inet_ntop(int, in void*, char*, socklen_t);
    int       inet_pton(int, in char*, void*);
}

//
// IPV6 (IP6)
//
/*
INET6_ADDRSTRLEN // from core.sys.posix.netinet.in_
*/

version( linux )
{
    const INET6_ADDRSTRLEN = 46;
}
else version( darwin )
{
    const INET6_ADDRSTRLEN = 46;
}
else version( freebsd )
{
    const INET6_ADDRSTRLEN = 46;
}
