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
module core.sys.posix.ucontext;

private import core.sys.posix.config;
public import core.sys.posix.signal; // for sigset_t, stack_t

extern (C):

//
// XOpen (XSI)
//
/*
mcontext_t

struct ucontext_t
{
    ucontext_t* uc_link;
    sigset_t    uc_sigmask;
    stack_t     uc_stack;
    mcontext_t  uc_mcontext;
}
*/

version( linux )
{

    version( X86_64 )
    {
        private
        {
            struct _libc_fpxreg
            {
                ushort[4] significand;
                ushort    exponent;
                ushort[3] padding;
            }

            struct _libc_xmmreg
            {
                uint[4] element;
            }

            struct _libc_fpstate
            {
                ushort           cwd;
                ushort           swd;
                ushort           ftw;
                ushort           fop;
                ulong            rip;
                ulong            rdp;
                uint             mxcsr;
                uint             mxcr_mask;
                _libc_fpxreg[8]  _st;
                _libc_xmmreg[16] _xmm;
                uint[24]         padding;
            }

            enum NGREG = 23;

            alias c_long            greg_t;
            alias greg_t[NGREG]     gregset_t;
            alias _libc_fpstate*    fpregset_t;
        }

        struct mcontext_t
        {
            gregset_t   gregs;
            fpregset_t  fpregs;
            c_ulong[8]  __reserved1;
        }

        struct ucontext_t
        {
            c_ulong         uc_flags;
            ucontext_t*     uc_link;
            stack_t         uc_stack;
            mcontext_t      uc_mcontext;
            sigset_t        uc_sigmask;
            _libc_fpstate   __fpregs_mem;
        }
    }
    else version( X86 )
    {
        private
        {
            struct _libc_fpreg
            {
              ushort[4] significand;
              ushort    exponent;
            }

            struct _libc_fpstate
            {
              c_ulong           cw;
              c_ulong           sw;
              c_ulong           tag;
              c_ulong           ipoff;
              c_ulong           cssel;
              c_ulong           dataoff;
              c_ulong           datasel;
              _libc_fpreg[8]    _st;
              c_ulong           status;
            }

            enum NGREG = 19;

            alias int               greg_t;
            alias greg_t[NGREG]     gregset_t;
            alias _libc_fpstate*    fpregset_t;
        }

        struct mcontext_t
        {
            gregset_t   gregs;
            fpregset_t  fpregs;
            c_ulong     oldmask;
            c_ulong     cr2;
        }

        struct ucontext_t
        {
            c_ulong         uc_flags;
            ucontext_t*     uc_link;
            stack_t         uc_stack;
            mcontext_t      uc_mcontext;
            sigset_t        uc_sigmask;
            _libc_fpstate   __fpregs_mem;
        }
    }
}
else version( FreeBSD )
{
    // <machine/ucontext.h>
    version( X86_64 )
    {
      alias long __register_t;
      alias uint __uint32_t;
      alias ushort __uint16_t;

      struct mcontext_t {
       __register_t    mc_onstack;
       __register_t    mc_rdi;
       __register_t    mc_rsi;
       __register_t    mc_rdx;
       __register_t    mc_rcx;
       __register_t    mc_r8;
       __register_t    mc_r9;
       __register_t    mc_rax;
       __register_t    mc_rbx;
       __register_t    mc_rbp;
       __register_t    mc_r10;
       __register_t    mc_r11;
       __register_t    mc_r12;
       __register_t    mc_r13;
       __register_t    mc_r14;
       __register_t    mc_r15;
       __uint32_t      mc_trapno;
       __uint16_t      mc_fs;
       __uint16_t      mc_gs;
       __register_t    mc_addr;
       __uint32_t      mc_flags;
       __uint16_t      mc_es;
       __uint16_t      mc_ds;
       __register_t    mc_err;
       __register_t    mc_rip;
       __register_t    mc_cs;
       __register_t    mc_rflags;
       __register_t    mc_rsp;
       __register_t    mc_ss;

       long    mc_len;                 /* sizeof(mcontext_t) */

       long    mc_fpformat;
       long    mc_ownedfp;

       align(16)
       long    mc_fpstate[64];

       __register_t    mc_fsbase;
       __register_t    mc_gsbase;

       long    mc_spare[6];
      }
    }
    else version( X86 )
    {
        alias int __register_t;

        struct mcontext_t
        {
            __register_t    mc_onstack;
            __register_t    mc_gs;
            __register_t    mc_fs;
            __register_t    mc_es;
            __register_t    mc_ds;
            __register_t    mc_edi;
            __register_t    mc_esi;
            __register_t    mc_ebp;
            __register_t    mc_isp;
            __register_t    mc_ebx;
            __register_t    mc_edx;
            __register_t    mc_ecx;
            __register_t    mc_eax;
            __register_t    mc_trapno;
            __register_t    mc_err;
            __register_t    mc_eip;
            __register_t    mc_cs;
            __register_t    mc_eflags;
            __register_t    mc_esp;
            __register_t    mc_ss;

            int             mc_len;
            int             mc_fpformat;
            int             mc_ownedfp;
            int[1]          mc_spare1;

            align(16)
            int[128]        mc_fpstate;

            __register_t    mc_fsbase;
            __register_t    mc_gsbase;

            int[6]          mc_spare2;
        }
    }

    // <ucontext.h>
    enum UCF_SWAPPED = 0x00000001;

    struct ucontext_t
    {
        sigset_t        uc_sigmask;
        mcontext_t      uc_mcontext;

        ucontext_t*     uc_link;
        stack_t         uc_stack;
        int             uc_flags;
        int[4]          __spare__;
    }
}

//
// Obsolescent (OB)
//
/*
int  getcontext(ucontext_t*);
void makecontext(ucontext_t*, void function(), int, ...);
int  setcontext(in ucontext_t*);
int  swapcontext(ucontext_t*, in ucontext_t*);
*/

static if( is( ucontext_t ) )
{
    int  getcontext(ucontext_t*);
    void makecontext(ucontext_t*, void function(), int, ...);
    int  setcontext(in ucontext_t*);
    int  swapcontext(ucontext_t*, in ucontext_t*);
}
