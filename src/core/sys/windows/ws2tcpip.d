/***********************************************************************\
*                              ws2tcpip.d                               *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*                 Translated from MinGW Windows headers                 *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/

module core.sys.windows.ws2tcpip;

import core.sys.windows.w32api;
//import core.sys.windows.winbase;
import core.sys.windows.windef;
//import core.sys.windows.basetyps;
import core.sys.windows.winsock2;

enum {
	IP_OPTIONS					= 1,

	IP_HDRINCL					= 2,
	IP_TOS						= 3,
	IP_TTL						= 4,
	IP_MULTICAST_IF				= 9,
	IP_MULTICAST_TTL			= 10,
	IP_MULTICAST_LOOP			= 11,
	IP_ADD_MEMBERSHIP			= 12,
	IP_DROP_MEMBERSHIP			= 13,
	IP_DONTFRAGMENT				= 14,
	IP_ADD_SOURCE_MEMBERSHIP	= 15,
	IP_DROP_SOURCE_MEMBERSHIP	= 16,
	IP_BLOCK_SOURCE				= 17,
	IP_UNBLOCK_SOURCE			= 18,
	IP_PKTINFO					= 19
}	

enum {
	IPV6_UNICAST_HOPS		= 4,
	IPV6_MULTICAST_IF		= 9,
	IPV6_MULTICAST_HOPS		= 10,
	IPV6_MULTICAST_LOOP		= 11,
	IPV6_ADD_MEMBERSHIP		= 12,
	IPV6_DROP_MEMBERSHIP	= 13,
	IPV6_JOIN_GROUP			= IPV6_ADD_MEMBERSHIP,
	IPV6_LEAVE_GROUP		= IPV6_DROP_MEMBERSHIP,
	IPV6_PKTINFO			= 19
}

const IP_DEFAULT_MULTICAST_TTL = 1;
const IP_DEFAULT_MULTICAST_LOOP = 1;
const IP_MAX_MEMBERSHIPS = 20;

const TCP_EXPEDITED_1122 = 2;

const UDP_NOCHECKSUM = 1;

enum {
	IFF_UP				= 1,
	IFF_BROADCAST		= 2,
	IFF_LOOPBACK		= 4,
	IFF_POINTTOPOINT	= 8,
	IFF_MULTICAST		= 16
}

const SIO_GET_INTERFACE_LIST = _IOR!('t', 127, u_long);

const INET_ADDRSTRLEN	= 16;
const INET6_ADDRSTRLEN	= 46;

const NI_MAXHOST	= 1025;
const NI_MAXSERV	= 32;

const NI_NOFQDN			= 0x01;
const NI_NUMERICHOST	= 0x02;
const NI_NAMEREQD		= 0x04;
const NI_NUMERICSERV	= 0x08;
const NI_DGRAM			= 0x10;

const AI_PASSIVE		= 1;
const AI_CANONNAME		= 2;
const AI_NUMERICHOST	= 4;

const EAI_AGAIN		= WSATRY_AGAIN;
const EAI_BADFLAGS	= WSAEINVAL;
const EAI_FAIL		= WSANO_RECOVERY;
const EAI_FAMILY	= WSAEAFNOSUPPORT;
const EAI_MEMORY	= WSA_NOT_ENOUGH_MEMORY;
const EAI_NODATA	= WSANO_DATA;
const EAI_NONAME	= WSAHOST_NOT_FOUND;
const EAI_SERVICE	= WSATYPE_NOT_FOUND;
const EAI_SOCKTYPE	= WSAESOCKTNOSUPPORT;

struct ip_mreq {
	IN_ADDR imr_multiaddr;
	IN_ADDR imr_interface;
}

struct ip_mreq_source {
	IN_ADDR imr_multiaddr;
	IN_ADDR imr_sourceaddr;
	IN_ADDR imr_interface;
}

struct ip_msfilter {
	IN_ADDR		imsf_multiaddr;
	IN_ADDR		imsf_interface;
	u_long		imsf_fmode;
	u_long		imsf_numsrc;
	IN_ADDR[1]	imsf_slist;
}

template IP_MSFILTER_SIZE(ULONG numsrc) {
	const DWORD IP_MSFILTER_SIZE = ip_msfilter.sizeof - IN_ADDR.sizeof + numsrc * IN_ADDR.sizeof;
}

struct IN_PKTINFO {
	IN_ADDR	ipi_addr;
	UINT	ipi_ifindex;
}

struct IN6_ADDR {
	union {
		u_char[16]	_S6_u8;
		u_short[8]	_S6_u16;
		u_long[4]	_S6_u32;
	}
}
alias IN6_ADDR* PIN6_ADDR, LPIN6_ADDR;

struct SOCKADDR_IN6 {
	short sin6_family;
	u_short sin6_port;
	u_long sin6_flowinfo;
	IN6_ADDR sin6_addr;
	u_long sin6_scope_id;
};
alias SOCKADDR_IN6* PSOCKADDR_IN6, LPSOCKADDR_IN6;

extern IN6_ADDR in6addr_any;
extern IN6_ADDR in6addr_loopback;

/+ TODO: 
#define IN6_ARE_ADDR_EQUAL(a, b)	\
    (memcmp ((void*)(a), (void*)(b), sizeof (struct in6_addr)) == 0)

#define IN6_IS_ADDR_UNSPECIFIED(_addr) \
	(   (((const u_long *)(_addr))[0] == 0)	\
	 && (((const u_long *)(_addr))[1] == 0)	\
	 && (((const u_long *)(_addr))[2] == 0)	\
	 && (((const u_long *)(_addr))[3] == 0))

#define IN6_IS_ADDR_LOOPBACK(_addr) \
	(   (((const u_long *)(_addr))[0] == 0)	\
	 && (((const u_long *)(_addr))[1] == 0)	\
	 && (((const u_long *)(_addr))[2] == 0)	\
	 && (((const u_long *)(_addr))[3] == 0x01000000))

#define IN6_IS_ADDR_MULTICAST(_addr) (((const u_char *) (_addr))[0] == 0xff)

#define IN6_IS_ADDR_LINKLOCAL(_addr) \
	(   (((const u_char *)(_addr))[0] == 0xfe)	\
	 && ((((const u_char *)(_addr))[1] & 0xc0) == 0x80))

#define IN6_IS_ADDR_SITELOCAL(_addr) \
	(   (((const u_char *)(_addr))[0] == 0xfe)	\
	 && ((((const u_char *)(_addr))[1] & 0xc0) == 0xc0))

#define IN6_IS_ADDR_V4MAPPED(_addr) \
	(   (((const u_long *)(_addr))[0] == 0)		\
	 && (((const u_long *)(_addr))[1] == 0)		\
	 && (((const u_long *)(_addr))[2] == 0xffff0000))

#define IN6_IS_ADDR_V4COMPAT(_addr) \
	(   (((const u_long *)(_addr))[0] == 0)		\
	 && (((const u_long *)(_addr))[1] == 0)		\
	 && (((const u_long *)(_addr))[2] == 0)		\
	 && (((const u_long *)(_addr))[3] != 0)		\
	 && (((const u_long *)(_addr))[3] != 0x01000000))

#define IN6_IS_ADDR_MC_NODELOCAL(_addr)	\
	(   IN6_IS_ADDR_MULTICAST(_addr)		\
	 && ((((const u_char *)(_addr))[1] & 0xf) == 0x1)) 

#define IN6_IS_ADDR_MC_LINKLOCAL(_addr)	\
	(   IN6_IS_ADDR_MULTICAST (_addr)		\
	 && ((((const u_char *)(_addr))[1] & 0xf) == 0x2))

#define IN6_IS_ADDR_MC_SITELOCAL(_addr)	\
	(   IN6_IS_ADDR_MULTICAST(_addr)		\
	 && ((((const u_char *)(_addr))[1] & 0xf) == 0x5))

#define IN6_IS_ADDR_MC_ORGLOCAL(_addr)	\
	(   IN6_IS_ADDR_MULTICAST(_addr)		\
	 && ((((const u_char *)(_addr))[1] & 0xf) == 0x8))

#define IN6_IS_ADDR_MC_GLOBAL(_addr)	\
	(   IN6_IS_ADDR_MULTICAST(_addr)	\
	 && ((((const u_char *)(_addr))[1] & 0xf) == 0xe))
+/

alias int socklen_t;

struct IPV6_MREG {
	IN6_ADDR	ipv6mr_multiaddr;
	uint		ipv6mr_interface;
}

struct IN6_PKTINFO {
	IN6_ADDR	ipi6_addr;
	UINT		ipi6_ifindex;
}

struct addrinfo {
	int			ai_flags;
	int			ai_family;
	int			ai_socktype;
	int			ai_protocol;
	size_t		ai_addrlen;
	char*		ai_canonname;
	SOCKADDR*	ai_addr;
	addrinfo*	ai_next;
}

extern(Windows) {
	static if (_WIN32_WINNT >= 0x501) {
		void freeaddrinfo(addrinfo*);
		int getaddrinfo (const(char)*, const(char)*, const(addrinfo)*, addrinfo**);
		int getnameinfo(const(SOCKADDR)*, socklen_t, char*, DWORD, char*, DWORD, int);
	}
}

/+ TODO
static __inline char*
gai_strerrorA(int ecode)
{
	static char[1024+1] message;
	DWORD dwFlags = FORMAT_MESSAGE_FROM_SYSTEM
	              | FORMAT_MESSAGE_IGNORE_INSERTS
		      | FORMAT_MESSAGE_MAX_WIDTH_MASK;
	DWORD dwLanguageId = MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);
  	FormatMessageA(dwFlags, NULL, ecode, dwLanguageId, (LPSTR)message, 1024, NULL);
	return message;
}
static __inline WCHAR*
gai_strerrorW(int ecode)
{
	static WCHAR[1024+1] message;
	DWORD dwFlags = FORMAT_MESSAGE_FROM_SYSTEM
	              | FORMAT_MESSAGE_IGNORE_INSERTS
		      | FORMAT_MESSAGE_MAX_WIDTH_MASK;
	DWORD dwLanguageId = MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);
  	FormatMessageW(dwFlags, NULL, ecode, dwLanguageId, (LPWSTR)message, 1024, NULL);
	return message;
}
#ifdef UNICODE
#define gai_strerror gai_strerrorW
#else
#define gai_strerror gai_strerrorA
#endif
+/

extern(Windows) {
	INT getnameinfo(SOCKADDR* pSockaddr, socklen_t SockaddrLength,
		PCHAR pNodeBuffer, DWORD NodeBufferSize, PCHAR pServiceBuffer,
		DWORD ServiceBufferSize, INT Flags);

	static if (_WIN32_WINNT >= 0x502) {
		INT GetNameInfoW(SOCKADDR* pSockaddr, socklen_t SockaddrLength,
			PWCHAR pNodeBuffer, DWORD NodeBufferSize, PWCHAR pServiceBuffer,
			DWORD ServiceBufferSize, INT Flags);

		alias getnameinfo GetNameInfoA;

		version(Unicode) {
			alias GetNameInfoW GetNameInfo;
		} else {
			alias GetNameInfoA GetNameInfo;
		}
	}
}
