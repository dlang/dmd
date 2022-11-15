/**
 * Taken from druntime/rt/trace.d
 * Contains support code for code profiling.
 *
 * Copyright: Copyright Digital Mars 1995 - 2015.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 */

module dmd.queryperf;

version (Windows)
{
    extern (Windows)
    {
        export int QueryPerformanceCounter(ulong *);
    }
}
else version (AArch64)
{
    // We cannot use ldc.intrinsics.llvm_readcyclecounter because that is not an accurate
    // time counter (it is a counter of CPU cycles, where here we want a time clock).
    // Also, priviledged execution rights are needed to enable correct counting with
    // ldc.intrinsics.llvm_readcyclecounter on AArch64.
    extern (D) void QueryPerformanceCounter(timer_t* ctr)
    {
        asm { "mrs %0, cntvct_el0" : "=r" (*ctr); }
    }
    extern (D) void QueryPerformanceFrequency(timer_t* freq)
    {
        asm { "mrs %0, cntfrq_el0" : "=r" (*freq); }
    }
}
else version (LDC)
{
    extern (D) void QueryPerformanceCounter(timer_t* ctr)
    {
        import ldc.intrinsics: llvm_readcyclecounter;
        *ctr = llvm_readcyclecounter();
    }
}
else version (D_InlineAsm_X86)
{
    extern (D)
    {
        void QueryPerformanceCounter(ulong* ctr)
        {
            asm
            {
                naked                   ;
                mov       ECX,EAX       ;
                rdtsc                   ;
                mov   [ECX],EAX         ;
                mov   [ECX+4],EDX        ;
                ret                     ;
            }
        }
    }
}
else version (D_InlineAsm_X86_64)
{
    extern (D)
    {
        void QueryPerformanceCounter(ulong* ctr)
        {
            asm
            {
                naked                   ;
                rdtsc                   ;
                mov   [RDI],EAX         ;
                mov   [RDI+4],EDX        ;
                ret                     ;
            }
        }
    }
}
else
{
    static assert(0);
}
