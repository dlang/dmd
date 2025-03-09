#define __alignof__ _Alignof

#define BIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD

#undef __SIZEOF_INT128__

#ifdef _WIN32
#define __pragma(a)
#define _Pragma(a)
#endif

#define _FILE_OFFSET_BITS 64

// Skip header ucrt/fenv.h
#define _FENV

#include <sys/stat.h>
#include <sys/types.h>
#if __has_include(<termios.h>)
#include <termios.h>
#endif
#if __has_include(<sys/socket.h>)
#include <sys/socket.h>
#endif
#if __has_include(<pwd.h>)
#include <pwd.h>
#endif
#if __has_include(<sys/statvfs.h>)
#include <sys/statvfs.h>
#endif
#include <time.h>
#if __has_include(<unistd.h>)
#include <unistd.h>
#endif
#if __has_include(<iconv.h>)
#include <iconv.h>
#endif
#if __has_include(<aio.h>)
#include <aio.h>
#endif
#if __has_include(<semaphore.h>)
#include <semaphore.h>
#endif
#if __has_include(<signal.h>)
#include <signal.h>
#endif
#if __has_include(<sys/wait.h>)
#include <sys/wait.h>
#endif
#if __has_include(<netdb.h>)
#include <netdb.h>
#endif
#if __has_include(<dirent.h>)
#include <dirent.h>
#endif
#if __has_include(<sched.h>)
#include <sched.h>
#endif
#if __has_include(<grp.h>)
#include <grp.h>
#endif
#if __has_include(<sys/utsname.h>)
#include <sys/utsname.h>
#endif
#include <setjmp.h>
#if __has_include(<arpa/inet.h>)
#include <arpa/inet.h>
#endif
#if __has_include(<sys/un.h>)
#include <sys/un.h>
#endif
#if __has_include(<locale.h>)
#include <locale.h>
#endif
#if __has_include(<poll.h>)
#include <poll.h>
#endif
#if __has_include(<utime.h>)
#include <utime.h>
#endif
#if __has_include(<sys/ipc.h>)
#include <sys/ipc.h>
#endif
#if __has_include(<sys/shm.h>)
#include <sys/shm.h>
#endif
#if __has_include(<spawn.h>)
#include <spawn.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#if __has_include(<sys/eventfd.h>)
#include <sys/eventfd.h>
#endif
#if __has_include(<stdatomic.h>) && !defined(__STDC_NO_ATOMICS__)
#include <stdatomic.h>
#endif
#if __has_include(<ifaddrs.h>)
#include <ifaddrs.h>
#endif
#ifdef linux
#include <linux/perf_event.h>
#include <linux/if_packet.h>
#include <linux/sysinfo.h>
#include <linux/elf.h>
#include <linux/if_arp.h>
#include <linux/prctl.h>
#include <linux/inotify.h>
#include <linux/io_uring.h>
#include <linux/eventpoll.h>
#endif
#include <math.h>
#include <fenv.h>
#include <inttypes.h>
#include <wctype.h>
#include <complex.h>
#if __has_include(<sys/msg.h>)
#include <sys/msg.h>
#endif
#include <wchar.h>
#if __has_include(<sys/resource.h>)
#include <sys/resource.h>
#endif

typedef struct stat stat_t;
typedef struct statvfs statvfs_t;
typedef struct timezone timezone_t;
typedef struct sysinfo sysinfo_t;

typedef unsigned long ulong_t;
typedef long slong_t;
typedef unsigned long c_ulong;
typedef long c_long;
typedef long double c_long_double;
typedef long __c_long;
typedef unsigned long __c_ulong;
typedef long long __c_longlong;
typedef unsigned long long __c_ulonglong;
typedef long cpp_long;
typedef unsigned long cpp_ulong;
typedef long long cpp_longlong;
typedef unsigned long long cpp_ulonglong;
typedef size_t cpp_size_t;
typedef ptrdiff_t cpp_ptrdiff_t;
typedef float _Complex __c_complex_float;
typedef double _Complex __c_complex_double;
typedef long double _Complex __c_complex_real;
typedef float _Complex c_complex_float;
typedef double _Complex c_complex_double;
typedef long double _Complex c_complex_real;

/* These types are defined as macros on Android and are not usable directly in ImportC. */
#ifdef ipc_perm
typedef ipc_perm ___realtype_ipc_perm;
#endif
#ifdef shmid_ds
typedef shmid_ds ___realtype_shmid_ds;
#endif
