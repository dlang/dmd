/**
 * D header file for POSIX.
 *
 * Copyright: David Nadlinger 2011.
 * License: $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors: $(WEB klickverbot.at, David Nadlinger)
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1,
 *     2004 Edition.
 */

module core.sys.posix.netdb;

import core.sys.posix.netinet.in_;

// For defining uint32_t as required by the standard.
public import core.stdc.inttypes : uint32_t;

// For defining socklen_t as required by the standard.
public import core.sys.posix.sys.socket;

extern(C):

struct hostent {
    char* h_name;
    char** h_aliases;
    int h_addrtype;
    int h_length;
    char** h_addr_list;

    // This is a compatibility define in C.
    char* h_addr() {
        return h_addr_list[0];
    }
}

struct netent {
    char* n_name;
    char** n_aliases;
    int n_addrtype;
    uint32_t n_net;
}

struct protoent {
    char* p_name;
    char** p_aliases;
    int p_proto;
}

struct servent {
    char* s_name;
    char** s_aliases;
    int s_port;
    char*s_proto;
}

enum IPPORT_RESERVED = 1024;

// h_error is officially obsolescent and would require an additional C helper
// module, so it has been omitted for now.

enum HOST_NOT_FOUND = 1;
enum TRY_AGAIN = 2;
enum NO_RECOVERY = 3;
enum NO_DATA = 4;

struct addrinfo {
    int ai_flags;
    int ai_family;
    int ai_socktype;
    int ai_protocol;
    socklen_t ai_addrlen;
    version (linux) {
        sockaddr* ai_addr;
        char* ai_canonname;
    } else {
        char* ai_canonname;
        sockaddr* ai_addr;
    }
    addrinfo* ai_next;
}

version (OSX) {
    enum {
        AI_PASSIVE = 0x1,
        AI_CANONNAME = 0x2,
        AI_NUMERICHOST = 0x4,
        AI_NUMERICSERV = 0x1000,
        AI_V4MAPPED = 0x800,
        AI_ALL = 0x100,
        AI_ADDRCONFIG = 0x400
    }
} else version (linux) {
    enum {
        AI_PASSIVE = 0x1,
        AI_CANONNAME = 0x2,
        AI_NUMERICHOST = 0x4,
        AI_NUMERICSERV = 0x400,
        AI_V4MAPPED = 0x8,
        AI_ALL = 0x10,
        AI_ADDRCONFIG = 0x20
    }
} else version (FreeBSD) {
    enum {
        AI_PASSIVE = 0x1,
        AI_CANONNAME = 0x2,
        AI_NUMERICHOST = 0x4,
        AI_NUMERICSERV = 0x8,
        AI_V4MAPPED = 0x800,
        AI_ALL = 0x100,
        AI_ADDRCONFIG = 0x400
    }
}

enum NI_MAXHOST = 1025;
enum NI_MAXSERV = 32;

version (OSX) {
    enum {
        NI_NOFQDN = 0x1,
        NI_NUMERICHOST = 0x2,
        NI_NAMEREQD = 0x4,
        NI_NUMERICSERV = 0x8,
        NI_DGRAM = 0x10,
        NI_WITHSCOPEID = 0x20
    }
} else version (linux) {
    enum {
        NI_NUMERICHOST = 1,
        NI_NUMERICSERV = 2,
        NI_NOFQDN = 4,
        NI_NAMEREQD = 8,
        NI_DGRAM = 16
    }
} else version (FreeBSD) {
    enum {
        NI_NOFQDN = 0x1,
        NI_NUMERICHOST = 0x2,
        NI_NAMEREQD = 0x4,
        NI_NUMERICSERV = 0x8,
        NI_DGRAM = 0x10,
        NI_WITHSCOPEID = 0x20
    }
}

enum SCOPE_DELIMITER = '%';

version (OSX) {
    enum {
        EAI_AGAIN = 2,
        EAI_BADFLAGS = 3,
        EAI_FAIL = 4,
        EAI_FAMILY = 5,
        EAI_MEMORY = 6,
        EAI_NONAME = 8,
        EAI_SERVICE = 9,
        EAI_SOCKTYPE = 10,
        EAI_SYSTEM = 11,
        EAI_OVERFLOW = 14
    }
} else version (linux) {
    enum {
        EAI_AGAIN = -3,
        EAI_BADFLAGS = -1,
        EAI_FAIL = -4,
        EAI_FAMILY = -6,
        EAI_MEMORY = -10,
        EAI_NONAME = -2,
        EAI_SERVICE = -8,
        EAI_SOCKTYPE = -7,
        EAI_SYSTEM = -11,
        EAI_OVERFLOW = -12
    }
} else version (FreeBSD) {
    enum {
        EAI_AGAIN = 2,
        EAI_BADFLAGS = 3,
        EAI_FAIL = 4,
        EAI_FAMILY = 5,
        EAI_MEMORY = 6,
        EAI_NONAME = 8,
        EAI_SERVICE = 9,
        EAI_SOCKTYPE = 10,
        EAI_SYSTEM = 11,
        EAI_OVERFLOW = 14
    }
}

void endhostent();
void endnetent();
void endprotoent();
void endservent();
void freeaddrinfo(addrinfo*);
const(char)* gai_strerror(int);
int getaddrinfo(const(char)*, const(char)*, const(addrinfo)*, addrinfo**);
hostent* gethostbyaddr(const(void)* , socklen_t, int);
hostent* gethostbyname(const(char)*);
hostent* gethostent();
int getnameinfo(const sockaddr*, socklen_t, char*, socklen_t, char*, socklen_t, int);
netent getnetbyaddr(uint32_t, int);
netent* getnetbyname(const(char)*);
netent* getnetent();
protoent* getprotobyname(const(char)*);
protoent* getprotobynumber(int);
protoent* getprotoent();
servent* getservbyname(const(char)*, const(char)*);
servent* getservbyport(int, const(char)*);
servent* getservent();
void sethostent(int);
void setnetent(int);
void setprotoent(int);
void setservent(int);
