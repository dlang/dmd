/**
 * D header file for POSIX.
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License:   $(HTTP www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 * Authors:   Sean Kelly,
              Alex Rønne Petersen
 * Standards: The Open Group Base Specifications Issue 6, IEEE Std 1003.1, 2004 Edition
 */

/*          Copyright Sean Kelly 2005 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.sys.types;

import core.sys.posix.config;
import core.stdc.stdint;
public import core.stdc.stddef;

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

version (Posix):
extern (C):

//
// bits/typesizes.h -- underlying types for *_t.
//
/*
__syscall_slong_t
__syscall_ulong_t
*/
version (CRuntime_Glibc)
{
    version (X86_64)
    {
        version (D_X32)
        {
            // X32 kernel interface is 64-bit.
            alias slong_t = long;
            alias ulong_t = ulong;
        }
        else
        {
            alias slong_t = c_long;
            alias ulong_t = c_ulong;
        }
    }
    else
    {
        alias slong_t = c_long;
        alias ulong_t = c_ulong;
    }
}
else
{
    alias slong_t = c_long;
    alias ulong_t = c_ulong;
}

//
// Required
//
/*
blkcnt_t
blksize_t
dev_t
gid_t
ino_t
mode_t
nlink_t
off_t
pid_t
size_t
ssize_t
time_t
uid_t
*/

version (linux)
{
  static if ( __USE_FILE_OFFSET64 )
  {
    alias blkcnt_t = long;
    alias ino_t = ulong;
    alias off_t = long;
  }
  else
  {
    alias blkcnt_t = slong_t;
    alias ino_t = ulong_t;
    alias off_t = slong_t;
  }
    // musl overrides blksize_t to int on some 64-bit architectures.
    // Default: long (https://git.musl-libc.org/cgit/musl/tree/include/alltypes.h.in?h=v1.2.3#n32)
    // AArch64: int (https://git.musl-libc.org/cgit/musl/tree/arch/aarch64/bits/alltypes.h.in?h=v1.2.3#n18)
    // RISCV64: int (https://git.musl-libc.org/cgit/musl/tree/arch/riscv64/bits/alltypes.h.in?h=v1.2.3#n12)
    // LoongArch64: int (https://git.musl-libc.org/cgit/musl/tree/arch/loongarch64/bits/alltypes.h.in?id=522bd54e#n18)
    version (CRuntime_Musl)
    {
        version (AArch64)
            alias blksize_t = int;
        else version (RISCV64)
            alias blksize_t = int;
        else version (LoongArch64)
            alias blksize_t = int;
        else
            alias blksize_t = slong_t;
    }
    else
        alias blksize_t = slong_t;

    alias dev_t = ulong;
    alias gid_t = uint;
    alias mode_t = uint;

    // musl defines nlink_t as unsigned _Reg (= unsigned int on 32-bit, unsigned long on 64-bit),
    // with arch-specific overrides.
    // Default: unsigned _Reg (https://git.musl-libc.org/cgit/musl/tree/include/alltypes.h.in?h=v1.2.3#n28)
    // MIPS64: unsigned (uint) (https://git.musl-libc.org/cgit/musl/tree/arch/mips64/bits/alltypes.h.in?h=v1.2.3#n22)
    // X86_64: _Reg=long, so unsigned long (https://git.musl-libc.org/cgit/musl/tree/arch/x86_64/bits/alltypes.h.in?h=v1.2.3#n3)
    version (CRuntime_Musl)
    {
        version (MIPS64)
            alias nlink_t = uint;
        else version (X86_64)
            alias nlink_t = ulong;
        else
            alias nlink_t = uint;
    }
    else
    {
        version (X86_64)
            alias nlink_t = ulong;
        else version (S390)
            alias nlink_t = size_t;
        else version (PPC64)
            alias nlink_t = size_t;
        else version (MIPS64)
            alias nlink_t = size_t;
        else version (HPPA64)
            alias nlink_t = size_t;
        else
            alias nlink_t = uint;
    }

    alias pid_t = int;
    //size_t (defined in core.stdc.stddef)
    alias ssize_t = c_long;
    alias uid_t = uint;

    version (CRuntime_Musl)
    {
        static assert(off_t.sizeof == 8);
        /**
         * Musl versions before v1.2.0 (up to v1.1.24) had different
         * definitions for `time_t` for 32 bits.
         * This was changed to always be 64 bits in v1.2.0:
         * https://musl.libc.org/time64.html
         * This change was only for 32 bits system and
         * didn't affect 64 bits systems
         *
         * To check previous definitions, `grep` for `time_t` in `arch/`,
         * and the result should be (in v1.1.24):
         * ---
         * // arch/riscv64/bits/alltypes.h.in:20:TYPEDEF long time_t;
         * // arch/s390x/bits/alltypes.h.in:17:TYPEDEF long time_t;
         * // arch/sh/bits/alltypes.h.in:21:TYPEDEF long time_t;
         * ---
         *
         * In order to be compatible with old versions of Musl,
         * one can recompile druntime with `CRuntime_Musl_Pre_Time64`.
         */
        version (D_X32)
           alias time_t = long;
        else version (CRuntime_Musl_Pre_Time64)
            alias time_t = c_long;
        else
            alias time_t = long;
    }
    else
    {
        alias time_t = slong_t;
    }
}
else version (Darwin)
{
    alias blkcnt_t = long;
    alias blksize_t = int;
    alias dev_t = int;
    alias gid_t = uint;
    alias ino_t = ulong;
    alias mode_t = ushort;
    alias nlink_t = ushort;
    alias off_t = long;
    alias pid_t = int;
    //size_t (defined in core.stdc.stddef)
    alias ssize_t = c_long;
    alias time_t = c_long;
    alias uid_t = uint;
}
else version (FreeBSD)
{
    import core.sys.freebsd.config;

    // https://github.com/freebsd/freebsd/blob/master/sys/sys/_types.h
    alias blkcnt_t = long;
    alias blksize_t = uint;

    static if (__FreeBSD_version >= 1200000)
    {
        alias dev_t = ulong;
        alias ino_t = ulong;
        alias nlink_t = ulong;
    }
    else
    {
        alias dev_t = uint;
        alias ino_t = uint;
        alias nlink_t = ushort;
    }

    alias gid_t = uint;
    alias mode_t = ushort;
    alias off_t = long;
    alias pid_t = int;
    //size_t (defined in core.stdc.stddef)
    alias ssize_t = c_long;
    alias time_t = c_long;
    alias uid_t = uint;
    alias fflags_t = uint; // non-standard
}
else version (NetBSD)
{
    alias blkcnt_t = long;
    alias blksize_t = int;
    alias dev_t = ulong;
    alias gid_t = uint;
    alias ino_t = ulong;
    alias mode_t = uint;
    alias nlink_t = uint;
    alias off_t = ulong;
    alias pid_t = int;
    //size_t (defined in core.stdc.stddef)
    alias ssize_t = c_long;
    alias time_t = c_long;
    alias uid_t = uint;
}
else version (OpenBSD)
{
    alias caddr_t = char*;
    alias blkcnt_t = long;
    alias blksize_t = int;
    alias dev_t = int;
    alias gid_t = uint;
    alias ino_t = ulong;
    alias mode_t = uint;
    alias nlink_t = uint;
    alias off_t = long;
    alias pid_t = int;
    //size_t (defined in core.stdc.stddef)
    alias ssize_t = c_long;
    alias time_t = long;
    alias uid_t = uint;
}
else version (DragonFlyBSD)
{
    alias blkcnt_t = long;
    alias blksize_t = long;
    alias dev_t = uint;
    alias gid_t = uint;
    alias ino_t = long;
    alias mode_t = ushort;
    alias nlink_t = uint;
    alias off_t = long;      //__off_t (defined in /usr/include/sys/stdint.h -> core.stdc.stddef)
    alias pid_t = int;      // size_t (defined in /usr/include/sys/stdint.h -> core.stdc.stddef)
    alias ssize_t = c_long;
    alias time_t = long;
    alias uid_t = uint;
}
else version (Solaris)
{
    alias caddr_t = char*;
    alias daddr_t = c_long;
    alias cnt_t = short;

    static if (__USE_FILE_OFFSET64)
    {
        alias blkcnt_t = long;
        alias ino_t = ulong;
        alias off_t = long;
    }
    else
    {
        alias blkcnt_t = c_long;
        alias ino_t = c_ulong;
        alias off_t = c_long;
    }

    version (D_LP64)
    {
        alias blkcnt64_t = blkcnt_t;
        alias ino64_t = ino_t;
        alias off64_t = off_t;
    }
    else
    {
        alias blkcnt64_t = long;
        alias ino64_t = ulong;
        alias off64_t = long;
    }

    alias blksize_t = uint;
    alias dev_t = c_ulong;
    alias gid_t = uid_t;
    alias mode_t = uint;
    alias nlink_t = uint;
    alias pid_t = int;
    alias ssize_t = c_long;
    alias time_t = c_long;
    alias uid_t = uint;
}
else
{
    static assert(false, "Unsupported platform");
}

//
// XOpen (XSI)
//
/*
clock_t
fsblkcnt_t
fsfilcnt_t
id_t
key_t
suseconds_t
useconds_t
*/

version (linux)
{
  static if ( __USE_FILE_OFFSET64 )
  {
    alias fsblkcnt_t = ulong;
    alias fsfilcnt_t = ulong;
  }
  else
  {
    alias fsblkcnt_t = ulong_t;
    alias fsfilcnt_t = ulong_t;
  }
    alias clock_t = slong_t;
    alias id_t = uint;
    alias key_t = int;
    alias suseconds_t = slong_t;
    alias useconds_t = uint;
}
else version (Darwin)
{
    alias fsblkcnt_t = uint;
    alias fsfilcnt_t = uint;
    alias clock_t = c_long;
    alias id_t = uint;
    alias key_t = int;
    alias suseconds_t = int;
    alias useconds_t = uint;
}
else version (FreeBSD)
{
    alias fsblkcnt_t = ulong;
    alias fsfilcnt_t = ulong;
    alias clock_t = c_long;
    alias id_t = long;
    alias key_t = c_long;
    alias suseconds_t = c_long;
    alias useconds_t = uint;
}
else version (NetBSD)
{
    alias fsblkcnt_t = ulong;
    alias fsfilcnt_t = ulong;
    alias clock_t = c_long;
    alias id_t = long;
    alias key_t = c_long;
    alias suseconds_t = c_long;
    alias useconds_t = uint;
}
else version (OpenBSD)
{
    alias fsblkcnt_t = ulong;
    alias fsfilcnt_t = ulong;
    alias clock_t = long;
    alias id_t = uint;
    alias key_t = c_long;
    alias suseconds_t = c_long;
    alias useconds_t = uint;
}
else version (DragonFlyBSD)
{
    alias fsblkcnt_t = ulong;
    alias fsfilcnt_t = ulong;
    alias clock_t = c_long;
    alias id_t = long;
    alias key_t = c_long;
    alias suseconds_t = c_long;
    alias useconds_t = uint;
}
else version (Solaris)
{
    static if (__USE_FILE_OFFSET64)
    {
        alias fsblkcnt_t = ulong;
        alias fsfilcnt_t = ulong;
    }
    else
    {
        alias fsblkcnt_t = c_ulong;
        alias fsfilcnt_t = c_ulong;
    }

    alias clock_t = c_long;
    alias id_t = int;
    alias key_t = int;
    alias suseconds_t = c_long;
    alias useconds_t = uint;

    alias taskid_t = id_t;
    alias projid_t = id_t;
    alias poolid_t = id_t;
    alias zoneid_t = id_t;
    alias ctid_t = id_t;
}
else
{
    static assert(false, "Unsupported platform");
}

//
// Thread (THR)
//
/*
pthread_attr_t
pthread_cond_t
pthread_condattr_t
pthread_key_t
pthread_mutex_t
pthread_mutexattr_t
pthread_once_t
pthread_rwlock_t
pthread_rwlockattr_t
pthread_t
*/

version (CRuntime_Glibc)
{
    version (X86)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (X86_64)
    {
        static if (__WORDSIZE == 64)
        {
            enum __SIZEOF_PTHREAD_ATTR_T = 56;
            enum __SIZEOF_PTHREAD_MUTEX_T = 40;
            enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
            enum __SIZEOF_PTHREAD_COND_T = 48;
            enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
            enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
            enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
            enum __SIZEOF_PTHREAD_BARRIER_T = 32;
            enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
        }
        else
        {
            enum __SIZEOF_PTHREAD_ATTR_T = 32;
            enum __SIZEOF_PTHREAD_MUTEX_T = 32;
            enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
            enum __SIZEOF_PTHREAD_COND_T = 48;
            enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
            enum __SIZEOF_PTHREAD_RWLOCK_T = 44;
            enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
            enum __SIZEOF_PTHREAD_BARRIER_T = 20;
            enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
        }
    }
    else version (AArch64)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 64;
        enum __SIZEOF_PTHREAD_MUTEX_T = 48;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 8;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 8;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 8;
    }
    else version (ARM)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (HPPA)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 48;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 64;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 48;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (IA64)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (MIPS32)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (MIPS64)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (PPC)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (PPC64)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (RISCV32)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (RISCV64)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (SPARC)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (SPARC64)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (S390)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (SystemZ)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else version (LoongArch64)
    {
        enum __SIZEOF_PTHREAD_ATTR_T = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
    }
    else
    {
        static assert (false, "Unsupported platform");
    }

    union pthread_attr_t
    {
        byte[__SIZEOF_PTHREAD_ATTR_T] __size;
        c_long __align;
    }

    private alias __atomic_lock_t = int;

    private struct _pthread_fastlock
    {
        c_long          __status;
        __atomic_lock_t __spinlock;
    }

    private alias _pthread_descr = void*;

    union pthread_cond_t
    {
        byte[__SIZEOF_PTHREAD_COND_T] __size;
        long  __align;
    }

    union pthread_condattr_t
    {
        byte[__SIZEOF_PTHREAD_CONDATTR_T] __size;
        int __align;
    }

    alias pthread_key_t = uint;

    union pthread_mutex_t
    {
        byte[__SIZEOF_PTHREAD_MUTEX_T] __size;
        c_long __align;
    }

    union pthread_mutexattr_t
    {
        byte[__SIZEOF_PTHREAD_MUTEXATTR_T] __size;
        int __align;
    }

    alias pthread_once_t = int;

    struct pthread_rwlock_t
    {
        byte[__SIZEOF_PTHREAD_RWLOCK_T] __size;
        c_long __align;
    }

    struct pthread_rwlockattr_t
    {
        byte[__SIZEOF_PTHREAD_RWLOCKATTR_T] __size;
        c_long __align;
    }

    alias pthread_t = c_ulong;
}
else version (CRuntime_Musl)
{
    version (D_LP64)
    {
        union pthread_attr_t
        {
            int[14] __i;
            ulong[7] __s;
        }

        union pthread_cond_t
        {
            int[12] __i;
            void*[6] __p;
        }

        union pthread_mutex_t
        {
            int[10] __i;
            void*[5] __p;
        }

        union pthread_rwlock_t
        {
            int[14] __i;
            void*[7] __p;
        }
    }
    else
    {
        union pthread_attr_t
        {
            int[9] __i;
            uint[9] __s;
        }

        union pthread_cond_t
        {
            int[12] __i;
            void*[12] __p;
        }

        union pthread_mutex_t
        {
            int[6] __i;
            void*[6] __p;
        }

        union pthread_rwlock_t
        {
            int[8] __i;
            void*[8] __p;
        }
    }

    struct pthread_rwlockattr_t
    {
        uint[2] __attr;
    }

    alias pthread_key_t = uint;

    struct pthread_condattr_t
    {
        uint __attr;
    }

    struct pthread_mutexattr_t
    {
        uint __attr;
    }

    alias pthread_once_t = int;

    alias pthread_t = c_ulong;
}
else version (Darwin)
{
    version (D_LP64)
    {
        enum __PTHREAD_SIZE__               = 8176;
        enum __PTHREAD_ATTR_SIZE__          = 56;
        enum __PTHREAD_MUTEXATTR_SIZE__     = 8;
        enum __PTHREAD_MUTEX_SIZE__         = 56;
        enum __PTHREAD_CONDATTR_SIZE__      = 8;
        enum __PTHREAD_COND_SIZE__          = 40;
        enum __PTHREAD_ONCE_SIZE__          = 8;
        enum __PTHREAD_RWLOCK_SIZE__        = 192;
        enum __PTHREAD_RWLOCKATTR_SIZE__    = 16;
    }
    else
    {
        enum __PTHREAD_SIZE__               = 4088;
        enum __PTHREAD_ATTR_SIZE__          = 36;
        enum __PTHREAD_MUTEXATTR_SIZE__     = 8;
        enum __PTHREAD_MUTEX_SIZE__         = 40;
        enum __PTHREAD_CONDATTR_SIZE__      = 4;
        enum __PTHREAD_COND_SIZE__          = 24;
        enum __PTHREAD_ONCE_SIZE__          = 4;
        enum __PTHREAD_RWLOCK_SIZE__        = 124;
        enum __PTHREAD_RWLOCKATTR_SIZE__    = 12;
    }

    struct pthread_handler_rec
    {
      void function(void*)  __routine;
      void*                 __arg;
      pthread_handler_rec*  __next;
    }

    struct pthread_attr_t
    {
        c_long                              __sig;
        byte[__PTHREAD_ATTR_SIZE__]         __opaque;
    }

    struct pthread_cond_t
    {
        c_long                              __sig;
        byte[__PTHREAD_COND_SIZE__]         __opaque;
    }

    struct pthread_condattr_t
    {
        c_long                              __sig;
        byte[__PTHREAD_CONDATTR_SIZE__]     __opaque;
    }

    alias pthread_key_t = c_ulong;

    struct pthread_mutex_t
    {
        c_long                              __sig;
        byte[__PTHREAD_MUTEX_SIZE__]        __opaque;
    }

    struct pthread_mutexattr_t
    {
        c_long                              __sig;
        byte[__PTHREAD_MUTEXATTR_SIZE__]    __opaque;
    }

    struct pthread_once_t
    {
        c_long                              __sig;
        byte[__PTHREAD_ONCE_SIZE__]         __opaque;
    }

    struct pthread_rwlock_t
    {
        c_long                              __sig;
        byte[__PTHREAD_RWLOCK_SIZE__]       __opaque;
    }

    struct pthread_rwlockattr_t
    {
        c_long                              __sig;
        byte[__PTHREAD_RWLOCKATTR_SIZE__]   __opaque;
    }

    private struct _opaque_pthread_t
    {
        c_long                  __sig;
        pthread_handler_rec*    __cleanup_stack;
        byte[__PTHREAD_SIZE__]  __opaque;
    }

    alias pthread_t = _opaque_pthread_t*;
}
else version (FreeBSD)
{
    alias lwpid_t = int; // non-standard

    alias pthread_attr_t = void*;
    alias pthread_cond_t = void*;
    alias pthread_condattr_t = void*;
    alias pthread_key_t = void*;
    alias pthread_mutex_t = void*;
    alias pthread_mutexattr_t = void*;
    alias pthread_once_t = void*;
    alias pthread_rwlock_t = void*;
    alias pthread_rwlockattr_t = void*;
    alias pthread_t = void*;
}
else version (NetBSD)
{
   struct pthread_queue_t {
         void*  ptqh_first;
         void** ptqh_last;
   }

    alias lwpid_t = int;
    alias pthread_spin_t = ubyte;
    struct pthread_attr_t {
        uint    pta_magic;
        int     pta_flags;
        void*   pta_private;
    }
    struct  pthread_spinlock_t {
        uint    pts_magic;
        pthread_spin_t  pts_spin;
        int             pts_flags;
    }
    struct pthread_cond_t {
        uint    ptc_magic;
        pthread_spin_t  ptc_lock;
        pthread_queue_t ptc_waiters;
        pthread_mutex_t *ptc_mutex;
        void*   ptc_private;
    }
    struct pthread_condattr_t {
        uint    ptca_magic;
        void    *ptca_private;
    }
    struct pthread_mutex_t {
        uint ptm_magic;
        pthread_spin_t  ptm_errorcheck;
        ubyte[3]         ptm_pad1;
        pthread_spin_t  ptm_interlock;
        ubyte[3] ptm_pad2;
        pthread_t ptm_owner;
        void* ptm_waiters;
        uint  ptm_recursed;
        void* ptm_spare2;
    }
    struct pthread_mutexattr_t{
        uint    ptma_magic;
        void*   ptma_private;
    }
    struct pthread_once_t{
        pthread_mutex_t pto_mutex;
        int     pto_done;
    }
    struct pthread_rwlock_t{
        uint    ptr_magic;

        pthread_spin_t  ptr_interlock;

        pthread_queue_t ptr_rblocked;
        pthread_queue_t ptr_wblocked;
        uint    ptr_nreaders;
        pthread_t ptr_owner;
        void    *ptr_private;
    }
    struct pthread_rwlockattr_t{
        uint    ptra_magic;
        void*   ptra_private;
    }

    alias pthread_key_t = uint;
    alias pthread_t = void*;
}
else version (OpenBSD)
{
    alias pthread_attr_t = void*;
    alias pthread_cond_t = void*;
    alias pthread_condattr_t = void*;
    alias pthread_key_t = int;
    alias pthread_mutex_t = void*;
    alias pthread_mutexattr_t = void*;

    private struct pthread_once
    {
        int state;
        pthread_mutex_t mutex;
    }
    alias pthread_once_t = pthread_once;

    alias pthread_rwlock_t = void*;
    alias pthread_rwlockattr_t = void*;
    alias pthread_t = void*;
}
else version (DragonFlyBSD)
{
    alias lwpid_t = int;

    alias pthread_attr_t = void*;
    alias pthread_cond_t = void*;
    alias pthread_condattr_t = void*;
    alias pthread_key_t = void*;
    alias pthread_mutex_t = void*;
    alias pthread_mutexattr_t = void*;

    private struct pthread_once
    {
        int state;
        pthread_mutex_t mutex;
    }
    alias pthread_once_t = pthread_once;

    alias pthread_rwlock_t = void*;
    alias pthread_rwlockattr_t = void*;
    alias pthread_t = void*;
}
else version (Solaris)
{
    alias pthread_t = uint;
    alias lwpid_t = int; // non-standard

    struct pthread_attr_t
    {
        void* __pthread_attrp;
    }

    struct pthread_cond_t
    {
        struct ___pthread_cond_flags
        {
            ubyte[4] __pthread_cond_flags;
            ushort __pthread_cond_type;
            ushort __pthread_cond_magic;
        }

        ___pthread_cond_flags __pthread_cond_flags;
        ulong __pthread_cond_data;
    }

    struct pthread_condattr_t
    {
        void* __pthread_condattrp;
    }

    struct pthread_rwlock_t
    {
        int __pthread_rwlock_readers;
        ushort __pthread_rwlock_type;
        ushort __pthread_rwlock_magic;
        pthread_mutex_t __pthread_rwlock_mutex;
        pthread_cond_t __pthread_rwlock_readercv;
        pthread_cond_t __pthread_rwlock_writercv;
    }

    struct pthread_rwlockattr_t
    {
        void* __pthread_rwlockattrp;
    }

    struct pthread_mutex_t
    {
        struct ___pthread_mutex_flags
        {
            ushort __pthread_mutex_flag1;
            ubyte __pthread_mutex_flag2;
            ubyte __pthread_mutex_ceiling;
            ushort __pthread_mutex_type;
            ushort __pthread_mutex_magic;
        }

        ___pthread_mutex_flags __pthread_mutex_flags;

        union ___pthread_mutex_lock
        {
            struct ___pthread_mutex_lock64
            {
                ubyte[8] __pthread_mutex_pad;
            }

            ___pthread_mutex_lock64 __pthread_mutex_lock64;

            struct ___pthread_mutex_lock32
            {
                uint __pthread_ownerpid;
                uint __pthread_lockword;
            }

            ___pthread_mutex_lock32 __pthread_mutex_lock32;
            ulong __pthread_mutex_owner64;
        }

        ___pthread_mutex_lock __pthread_mutex_lock;
        ulong __pthread_mutex_data;
    }

    struct pthread_mutexattr_t
    {
        void* __pthread_mutexattrp;
    }

    struct pthread_once_t
    {
        ulong[4] __pthread_once_pad;
    }

    alias pthread_key_t = uint;
}
else version (CRuntime_Bionic)
{
    struct pthread_attr_t
    {
        uint    flags;
        void*   stack_base;
        size_t  stack_size;
        size_t  guard_size;
        int     sched_policy;
        int     sched_priority;
        version (D_LP64) char[16] __reserved = 0;
    }

    struct pthread_cond_t
    {
        version (D_LP64)
            int[12] __private;
        else
            int[1] __private;
    }

    alias pthread_condattr_t = c_long;
    alias pthread_key_t = int;

    struct pthread_mutex_t
    {
        version (D_LP64)
            int[10] __private;
        else
            int[1] __private;
    }

    alias pthread_mutexattr_t = c_long;
    alias pthread_once_t = int;

    struct pthread_rwlock_t
    {
        version (D_LP64)
            int[14] __private;
        else
            int[10] __private;
    }

    alias pthread_rwlockattr_t = c_long;
    alias pthread_t = c_long;
}
else version (CRuntime_UClibc)
{
     version (X86_64)
     {
        enum __SIZEOF_PTHREAD_ATTR_T        = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T       = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T   = 4;
        enum __SIZEOF_PTHREAD_COND_T        = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T    = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T      = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T  = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T     = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
     }
     else version (MIPS32)
     {
        enum __SIZEOF_PTHREAD_ATTR_T        = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T       = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T   = 4;
        enum __SIZEOF_PTHREAD_COND_T        = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T    = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T      = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T  = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T     = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
     }
     else version (MIPS64)
     {
        enum __SIZEOF_PTHREAD_ATTR_T        = 56;
        enum __SIZEOF_PTHREAD_MUTEX_T       = 40;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T   = 4;
        enum __SIZEOF_PTHREAD_COND_T        = 48;
        enum __SIZEOF_PTHREAD_CONDATTR_T    = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T      = 56;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T  = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T     = 32;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
     }
     else version (ARM)
     {
        enum __SIZEOF_PTHREAD_ATTR_T = 36;
        enum __SIZEOF_PTHREAD_MUTEX_T = 24;
        enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
        enum __SIZEOF_PTHREAD_COND_T = 48;
        enum __SIZEOF_PTHREAD_COND_COMPAT_T = 12;
        enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
        enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
        enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
        enum __SIZEOF_PTHREAD_BARRIER_T = 20;
        enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;
     }
     else
     {
        static assert (false, "Architecture unsupported");
     }

    union pthread_attr_t
    {
        byte[__SIZEOF_PTHREAD_ATTR_T] __size;
        c_long __align;
    }

    union pthread_cond_t
    {
        struct data
        {
            int __lock;
            uint __futex;
            ulong __total_seq;
            ulong __wakeup_seq;
            ulong __woken_seq;
            void *__mutex;
            uint __nwaiters;
            uint __broadcast_seq;
        } data __data;
        byte[__SIZEOF_PTHREAD_COND_T] __size;
        long  __align;
    }

    union pthread_condattr_t
    {
        byte[__SIZEOF_PTHREAD_CONDATTR_T] __size;
        c_long __align;
    }

    alias pthread_key_t = uint;

    struct __pthread_slist_t
    {
      __pthread_slist_t* __next;
    }

    union pthread_mutex_t
    {
      struct __pthread_mutex_s
      {
        int __lock;
        uint __count;
        int __owner;
        /* KIND must stay at this position in the structure to maintain
           binary compatibility.  */
        int __kind;
        uint __nusers;
        union
        {
          int __spins;
          __pthread_slist_t __list;
        }
      }
      __pthread_mutex_s __data;
        byte[__SIZEOF_PTHREAD_MUTEX_T] __size;
        c_long __align;
    }

    union pthread_mutexattr_t
    {
        byte[__SIZEOF_PTHREAD_MUTEXATTR_T] __size;
        c_long __align;
    }

    alias pthread_once_t = int;

    struct pthread_rwlock_t
    {
        struct data
        {
            int __lock;
            uint __nr_readers;
            uint __readers_wakeup;
            uint __writer_wakeup;
            uint __nr_readers_queued;
            uint __nr_writers_queued;
            version (BigEndian)
            {
                ubyte __pad1;
                ubyte __pad2;
                ubyte __shared;
                ubyte __flags;
            }
            else
            {
                ubyte __flags;
                ubyte __shared;
                ubyte __pad1;
                ubyte __pad2;
            }
            int __writer;
        } data __data;
        byte[__SIZEOF_PTHREAD_RWLOCK_T] __size;
        c_long __align;
    }

    struct pthread_rwlockattr_t
    {
        byte[__SIZEOF_PTHREAD_RWLOCKATTR_T] __size;
        c_long __align;
    }

    alias pthread_t = c_ulong;
}
else
{
    static assert(false, "Unsupported platform");
}

//
// Barrier (BAR)
//
/*
pthread_barrier_t
pthread_barrierattr_t
*/

version (CRuntime_Glibc)
{
    struct pthread_barrier_t
    {
        byte[__SIZEOF_PTHREAD_BARRIER_T] __size;
        c_long __align;
    }

    struct pthread_barrierattr_t
    {
        byte[__SIZEOF_PTHREAD_BARRIERATTR_T] __size;
        int __align;
    }
}
else version (FreeBSD)
{
    alias pthread_barrier_t = void*;
    alias pthread_barrierattr_t = void*;
}
else version (NetBSD)
{
    alias pthread_barrier_t = void*;
    alias pthread_barrierattr_t = void*;
}
else version (OpenBSD)
{
    alias pthread_barrier_t = void*;
    alias pthread_barrierattr_t = void*;
}
else version (DragonFlyBSD)
{
    alias pthread_barrier_t = void*;
    alias pthread_barrierattr_t = void*;
}
else version (Darwin)
{
}
else version (Solaris)
{
    struct pthread_barrier_t
    {
        uint __pthread_barrier_count;
        uint __pthread_barrier_current;
        ulong __pthread_barrier_cycle;
        ulong __pthread_barrier_reserved;
        pthread_mutex_t __pthread_barrier_lock;
        pthread_cond_t __pthread_barrier_cond;
    }

    struct pthread_barrierattr_t
    {
        void* __pthread_barrierattrp;
    }
}
else version (CRuntime_Bionic)
{
}
else version (CRuntime_Musl)
{
    version (D_LP64)
    {
        union pthread_barrier_t
        {
            int[8] __i;
            void*[4] __p;
        }
    }
    else
    {
        union pthread_barrier_t
        {
            int[5] __i;
            void*[5] __p;
        }
    }

    struct pthread_barrierattr_t
    {
        uint __attr;
    }
}
else version (CRuntime_UClibc)
{
    struct pthread_barrier_t
    {
        byte[__SIZEOF_PTHREAD_BARRIER_T] __size;
        c_long __align;
    }

    struct pthread_barrierattr_t
    {
        byte[__SIZEOF_PTHREAD_BARRIERATTR_T] __size;
        int __align;
    }
}
else
{
    static assert(false, "Unsupported platform");
}

//
// Spin (SPN)
//
/*
pthread_spinlock_t
*/

version (CRuntime_Glibc)
{
    alias pthread_spinlock_t = int; // volatile
}
else version (FreeBSD)
{
    alias pthread_spinlock_t = void*;
}
else version (NetBSD)
{
    //already defined
}
else version (OpenBSD)
{
    alias pthread_spinlock_t = void*;
}
else version (DragonFlyBSD)
{
    alias pthread_spinlock_t = void*;
}
else version (Solaris)
{
    alias pthread_spinlock_t = pthread_mutex_t;
}
else version (CRuntime_UClibc)
{
    alias pthread_spinlock_t = int; // volatile
}
else version (CRuntime_Musl)
{
    alias pthread_spinlock_t = int;
}

//
// Timer (TMR)
//
/*
clockid_t
timer_t
*/

//
// Trace (TRC)
//
/*
trace_attr_t
trace_event_id_t
trace_event_set_t
trace_id_t
*/
