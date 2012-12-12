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
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.posix.ucontext;

private import core.sys.posix.config;
public import core.sys.posix.signal; // for sigset_t, stack_t

version (Posix):
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
        enum
        {
            REG_R8 = 0,
            REG_R9,
            REG_R10,
            REG_R11,
            REG_R12,
            REG_R13,
            REG_R14,
            REG_R15,
            REG_RDI,
            REG_RSI,
            REG_RBP,
            REG_RBX,
            REG_RDX,
            REG_RAX,
            REG_RCX,
            REG_RSP,
            REG_RIP,
            REG_EFL,
            REG_CSGSFS,     /* Actually short cs, gs, fs, __pad0.  */
            REG_ERR,
            REG_TRAPNO,
            REG_OLDMASK,
            REG_CR2
        }

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
        enum
        {
            REG_GS = 0,
            REG_FS,
            REG_ES,
            REG_DS,
            REG_EDI,
            REG_ESI,
            REG_EBP,
            REG_ESP,
            REG_EBX,
            REG_EDX,
            REG_ECX,
            REG_EAX,
            REG_TRAPNO,
            REG_ERR,
            REG_EIP,
            REG_CS,
            REG_EFL,
            REG_UESP,
            REG_SS
        }

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
    else version (MIPS)
    {
        private
        {
            enum NGREG  = 32;
            enum NFPREG = 32;

            alias ulong         greg_t;
            alias greg_t[NGREG] gregset_t;

            struct fpregset_t
            {
                union fp_r_t
                {
                    double[NFPREG]  fp_dregs;
                    static struct fp_fregs_t
                    {
                        float   _fp_fregs;
                        uint    _fp_pad;
                    } fp_fregs_t[NFPREG] fp_fregs;
                } fp_r_t fp_r;
            }
        }

        version (MIPS_O32)
        {
            struct mcontext_t
            {
                uint regmask;
                uint status;
                greg_t pc;
                gregset_t gregs;
                fpregset_t fpregs;
                uint fp_owned;
                uint fpc_csr;
                uint fpc_eir;
                uint used_math;
                uint dsp;
                greg_t mdhi;
                greg_t mdlo;
                c_ulong hi1;
                c_ulong lo1;
                c_ulong hi2;
                c_ulong lo2;
                c_ulong hi3;
                c_ulong lo3;
            }
        }
        else
        {
            struct mcontext_t
            {
                gregset_t gregs;
                fpregset_t fpregs;
                greg_t mdhi;
                greg_t hi1;
                greg_t hi2;
                greg_t hi3;
                greg_t mdlo;
                greg_t lo1;
                greg_t lo2;
                greg_t lo3;
                greg_t pc;
                uint fpc_csr;
                uint used_math;
                uint dsp;
                uint reserved;
            }
        }

        struct ucontext_t
        {
            c_ulong     uc_flags;
            ucontext_t* uc_link;
            stack_t     uc_stack;
            mcontext_t  uc_mcontext;
            sigset_t    uc_sigmask;
        }
    }
    else
        static assert(0, "unimplemented");
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
