/**
 * D header file for GNU/Linux.
 *
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Paul O'Neil
 */
module core.sys.linux.sys.socket;

public import core.sys.posix.sys.socket;

version (linux):
extern(C):
@nogc:
nothrow:

enum
{
    // Protocol families.
    PF_UNSPEC     = 0,
    PF_LOCAL      = 1,
    PF_UNIX       = PF_LOCAL,
    PF_FILE       = PF_LOCAL,
    PF_INET       = 2,
    PF_AX25       = 3,
    PF_NETROM     = 6,
    PF_BRIDGE     = 7,
    PF_ATMPVC     = 8,
    PF_X25        = 9,
    PF_INET6      = 10,
    PF_ROSE       = 11,
    PF_DECnet     = 12,
    PF_NETBEUI    = 13,
    PF_SECURITY   = 14,
    PF_KEY        = 15,
    PF_NETLINK    = 16,
    PF_ROUTE      = PF_NETLINK,
    PF_PACKET     = 17,
    PF_ASH        = 18,
    PF_ECONET     = 19,
    PF_ATMSVC     = 20,
    PF_RDS        = 21,
    PF_SNA        = 22,
    PF_IRDA       = 23,
    PF_PPPOX      = 24,
    PF_WANPIPE    = 25,
    PF_LLC        = 26,
    PF_IB         = 27,
    PF_MPLS       = 28,
    PF_CAN        = 29,
    PF_TIPC       = 30,
    PF_BLUETOOTH  = 31,
    PF_IUCV       = 32,
    PF_RXRPC      = 33,
    PF_ISDN       = 34,
    PF_PHONET     = 35,
    PF_IEEE802154 = 36,
    PF_CAIF       = 37,
    PF_ALG        = 38,
    PF_NFC        = 39,
    PF_VSOCK      = 40,
    PF_KCM        = 41,
    PF_QIPCRTR    = 42,
    PF_SMC        = 43,
    PF_MAX        = 44,

    // Address families.
    AF_LOCAL      = PF_LOCAL,
    AF_FILE       = AF_LOCAL,
    AF_AX25       = PF_AX25,
    AF_NETROM     = PF_NETROM,
    AF_BRIDGE     = PF_BRIDGE,
    AF_ATMPVC     = PF_ATMPVC,
    AF_X25        = PF_X25,
    AF_ROSE       = PF_ROSE,
    AF_DECnet     = PF_DECnet,
    AF_NETBEUI    = PF_NETBEUI,
    AF_SECURITY   = PF_SECURITY,
    AF_KEY        = PF_KEY,
    AF_NETLINK    = PF_NETLINK,
    AF_ROUTE      = PF_ROUTE,
    AF_PACKET     = PF_PACKET,
    AF_ASH        = PF_ASH,
    AF_ECONET     = PF_ECONET,
    AF_ATMSVC     = PF_ATMSVC,
    AF_RDS        = PF_RDS,
    AF_SNA        = PF_SNA,
    AF_IRDA       = PF_IRDA,
    AF_PPPOX      = PF_PPPOX,
    AF_WANPIPE    = PF_WANPIPE,
    AF_LLC        = PF_LLC,
    AF_IB         = PF_IB,
    AF_MPLS       = PF_MPLS,
    AF_CAN        = PF_CAN,
    AF_TIPC       = PF_TIPC,
    AF_BLUETOOTH  = PF_BLUETOOTH,
    AF_IUCV       = PF_IUCV,
    AF_RXRPC      = PF_RXRPC,
    AF_ISDN       = PF_ISDN,
    AF_PHONET     = PF_PHONET,
    AF_IEEE802154 = PF_IEEE802154,
    AF_CAIF       = PF_CAIF,
    AF_ALG        = PF_ALG,
    AF_NFC        = PF_NFC,
    AF_VSOCK      = PF_VSOCK,
    AF_KCM        = PF_KCM,
    AF_QIPCRTR    = PF_QIPCRTR,
    AF_SMC        = PF_SMC,
    AF_MAX        = PF_MAX,
}

// For getsockopt() and setsockopt()
enum
{
    SO_SECURITY_AUTHENTICATION       = 22,
    SO_SECURITY_ENCRYPTION_TRANSPORT = 23,
    SO_SECURITY_ENCRYPTION_NETWORK   = 24,

    SO_BINDTODEVICE            = 25,

    SO_ATTACH_FILTER           = 26,
    SO_DETACH_FILTER           = 27,
    SO_GET_FILTER              = SO_ATTACH_FILTER,

    SO_PEERNAME                = 28,
    SO_TIMESTAMP               = 29,
    SCM_TIMESTAMP              = SO_TIMESTAMP,

    SO_PASSSEC                 = 34,
    SO_TIMESTAMPNS             = 35,
    SCM_TIMESTAMPNS            = SO_TIMESTAMPNS,
    SO_MARK                    = 36,
    SO_TIMESTAMPING            = 37,
    SCM_TIMESTAMPING           = SO_TIMESTAMPING,
    SO_RXQ_OVFL                = 40,
    SO_WIFI_STATUS             = 41,
    SCM_WIFI_STATUS            = SO_WIFI_STATUS,
    SO_PEEK_OFF                = 42,
    SO_NOFCS                   = 43,
    SO_LOCK_FILTER             = 44,
    SO_SELECT_ERR_QUEUE        = 45,
    SO_BUSY_POLL               = 46,
    SO_MAX_PACING_RATE         = 47,
    SO_BPF_EXTENSIONS          = 48,
    SO_INCOMING_CPU            = 49,
    SO_ATTACH_BPF              = 50,
    SO_DETACH_BPF              = SO_DETACH_FILTER,
    SO_ATTACH_REUSEPORT_CBPF   = 51,
    SO_ATTACH_REUSEPORT_EBPF   = 52,
    SO_CNX_ADVICE              = 53,
    SCM_TIMESTAMPING_OPT_STATS = 54,
    SO_MEMINFO                 = 55,
    SO_INCOMING_NAPI_ID        = 56,
    SO_COOKIE                  = 57,
    SCM_TIMESTAMPING_PKTINFO   = 58,
    SO_PEERGROUPS              = 59,
    SO_ZEROCOPY                = 60,
}

enum : uint
{
    MSG_TRYHARD      = 0x04,
    MSG_PROXY        = 0x10,
    MSG_DONTWAIT     = 0x40,
    MSG_FIN          = 0x200,
    MSG_SYN          = 0x400,
    MSG_CONFIRM      = 0x800,
    MSG_RST          = 0x1000,
    MSG_ERRQUEUE     = 0x2000,
    MSG_MORE         = 0x8000,
    MSG_WAITFORONE   = 0x10000,
    MSG_BATCH        = 0x40000,
    MSG_ZEROCOPY     = 0x4000000,
    MSG_FASTOPEN     = 0x20000000,
    MSG_CMSG_CLOEXEC = 0x40000000
}
