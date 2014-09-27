/**
 * D header file for C99.
 *
 * $(C_HEADER_DESCRIPTION pubs.opengroup.org/onlinepubs/009695399/basedefs/fenv.h.html, fenv.h)
 *
 * Copyright: Copyright Sean Kelly 2005 - 2009.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly
 * Source:    $(DRUNTIMESRC core/stdc/_fenv.d)
 * Standards: ISO/IEC 9899:1999 (E)
 */

module core.stdc.fenv;

extern (C):
@system:
nothrow:
@nogc:

version( MinGW )
    version = GNUFP;
version( linux )
    version = GNUFP;

version( GNUFP )
{
    // https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/x86/fpu/bits/fenv.h
    version (X86)
    {
        struct fenv_t
        {
            ushort __control_word;
            ushort __unused1;
            ushort __status_word;
            ushort __unused2;
            ushort __tags;
            ushort __unused3;
            uint   __eip;
            ushort __cs_selector;
            ushort __opcode;
            uint   __data_offset;
            ushort __data_selector;
            ushort __unused5;
        }

        alias fexcept_t = ushort;
    }
    // https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/x86/fpu/bits/fenv.h
    else version (X86_64)
    {
        struct fenv_t
        {
            ushort __control_word;
            ushort __unused1;
            ushort __status_word;
            ushort __unused2;
            ushort __tags;
            ushort __unused3;
            uint   __eip;
            ushort __cs_selector;
            ushort __opcode;
            uint   __data_offset;
            ushort __data_selector;
            ushort __unused5;
            uint   __mxcsr;
        }

        alias fexcept_t = ushort;
    }
    // https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/mips/bits/fenv.h
    else version (MIPS32)
    {
        struct fenv_t
        {
            uint   __fp_control_register;
        }

        alias fexcept_t = ushort;
    }
    // https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/mips/bits/fenv.h
    else version (MIPS64)
    {
        struct fenv_t
        {
            uint   __fp_control_register;
        }

        alias fexcept_t = ushort;
    }
    // https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/arm/bits/fenv.h
    else version (ARM)
    {
        struct fenv_t
        {
            uint __cw;
        }

        alias fexcept_t = uint;
    }
    // https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/powerpc/bits/fenv.h
    else version (PPC64)
    {
        alias fenv_t = double;
        alias fexcept_t = uint;
    }
    else
    {
        static assert(0, "Unimplemented architecture");
    }
}
else version( CRuntime_DigitalMars )
{
    struct fenv_t
    {
        ushort    status;
        ushort    control;
        ushort    round;
        ushort[2] reserved;
    }
    alias fexcept_t = int;
}
else version( CRuntime_Microsoft )
{
    struct fenv_t
    {
        uint ctl;
        uint stat;
    }

    alias fexcept_t = uint;
}
else version ( OSX )
{
    version ( BigEndian )
    {
        alias uint fenv_t;
        alias uint fexcept_t;
    }
    version ( LittleEndian )
    {
        struct fenv_t
        {
            ushort  __control;
            ushort  __status;
            uint    __mxcsr;
            byte[8] __reserved;
        }

        alias ushort fexcept_t;
    }
}
else version ( FreeBSD )
{
    struct fenv_t
    {
        ushort __control;
        ushort __mxcsr_hi;
        ushort __status;
        ushort __mxcsr_lo;
        uint __tag;
        byte[16] __other;
    }

    alias ushort fexcept_t;
}
else version( Android )
{
    version(X86)
    {
        struct fenv_t
        {
            ushort   __control;
            ushort   __mxcsr_hi;
            ushort   __status;
            ushort   __mxcsr_lo;
            uint     __tag;
            byte[16] __other;
        }

        alias ushort fexcept_t;
    }
    else
    {
        static assert(false, "Architecture not supported.");
    }
}
else version( Solaris )
{
    import core.stdc.config : c_ulong;

    enum FEX_NUM_EXC = 12;

    struct fex_handler_t
    {
        int             __mode;
        void function() __handler;
    }

    struct fenv_t
    {
        fex_handler_t[FEX_NUM_EXC]  __handler;
        c_ulong                     __fsr;
    }

    alias int fexcept_t;
}
else
{
    static assert( false, "Unsupported platform" );
}

enum
{
    FE_INVALID      = 1, ///
    FE_DENORMAL     = 2, /// non-standard
    FE_DIVBYZERO    = 4, ///
    FE_OVERFLOW     = 8, ///
    FE_UNDERFLOW    = 0x10, ///
    FE_INEXACT      = 0x20, ///
    FE_ALL_EXCEPT   = 0x3F, ///
    FE_TONEAREST    = 0, ///
    FE_UPWARD       = 0x800, ///
    FE_DOWNWARD     = 0x400, ///
    FE_TOWARDZERO   = 0xC00, ///
}

version( GNUFP )
{
    ///
    enum FE_DFL_ENV = cast(fenv_t*)(-1);
}
else version( CRuntime_DigitalMars )
{
    private extern __gshared fenv_t _FE_DFL_ENV;
    ///
    enum fenv_t* FE_DFL_ENV = &_FE_DFL_ENV;
}
else version( CRuntime_Microsoft )
{
    private immutable fenv_t _Fenv0 = {0, 0};
    ///
    enum FE_DFL_ENV = &_Fenv0;
}
else version( OSX )
{
    private extern __gshared fenv_t _FE_DFL_ENV;
    ///
    enum FE_DFL_ENV = &_FE_DFL_ENV;
}
else version( FreeBSD )
{
    private extern const fenv_t __fe_dfl_env;
    ///
    enum FE_DFL_ENV = &__fe_dfl_env;
}
else version( Android )
{
    private extern const fenv_t __fe_dfl_env;
    ///
    enum FE_DFL_ENV = &__fe_dfl_env;
}
else version( Solaris )
{
    private extern const fenv_t __fenv_def_env;
    ///
    enum FE_DFL_ENV = &__fenv_def_env;
}
else
{
    static assert( false, "Unsupported platform" );
}

///
int feraiseexcept(int excepts);
///
int feclearexcept(int excepts);

///
int fetestexcept(int excepts);
///
int feholdexcept(fenv_t* envp);

///
int fegetexceptflag(fexcept_t* flagp, int excepts);
///
int fesetexceptflag(in fexcept_t* flagp, int excepts);

///
int fegetround();
///
int fesetround(int round);

///
int fegetenv(fenv_t* envp);
///
int fesetenv(in fenv_t* envp);
///
int feupdateenv(in fenv_t* envp);
