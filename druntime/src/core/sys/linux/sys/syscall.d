/**
 * D header file for GNU/Linux
 *
 * $(LINK2 https://sourceware.org/git/?p=glibc.git;a=blob;f=sysdeps/unix/sysv/linux/sys/syscall.h, glibc sys/syscall.h)
 */

module core.sys.linux.sys.syscall;

version (linux):
extern (C):
@nogc:
nothrow:

version (HPPA)    version = HPPA_Any;
version (HPPA64)  version = HPPA_Any;
version (PPC)     version = PPC_Any;
version (PPC64)   version = PPC_Any;
version (RISCV32) version = RISCV_Any;
version (RISCV64) version = RISCV_Any;
version (S390)    version = IBMZ_Any;
version (SPARC)   version = SPARC_Any;
version (SPARC64) version = SPARC_Any;
version (SystemZ) version = IBMZ_Any;

// <asm/unistd.h>
// List the numbers of the system calls the system knows.
version (X86_64)
{
    version (D_X32)
        enum __NR_perf_event_open = 0x40000000 + 298;
    else
        enum __NR_perf_event_open = 298;
}
else version (X86)
{
    enum __NR_perf_event_open = 336;
}
else version (ARM)
{
    enum __NR_perf_event_open = 364;
}
else version (AArch64)
{
    enum __NR_perf_event_open = 241;
}
else version (HPPA_Any)
{
    enum __NR_perf_event_open = 318;
}
else version (IBMZ_Any)
{
    enum __NR_perf_event_open = 331;
}
else version (MIPS32)
{
    enum __NR_perf_event_open = 4333;
}
else version (MIPS64)
{
    version (MIPS_N32)
        enum __NR_perf_event_open = 6296;
    else version (MIPS_N64)
        enum __NR_perf_event_open = 5292;
    else
        static assert(0, "Architecture not supported");
}
else version (PPC_Any)
{
    enum __NR_perf_event_open = 319;
}
else version (RISCV_Any)
{
    enum __NR_perf_event_open = 241;
}
else version (SPARC_Any)
{
    enum __NR_perf_event_open = 327;
}
else version (LoongArch64)
{
    enum __NR_perf_event_open = 241;
}
else
{
    static assert(0, "Architecture not supported");
}

// <bits/syscall.h>
// Defines SYS_* names for the __NR_* numbers of known names.
enum SYS_perf_event_open = __NR_perf_event_open;
