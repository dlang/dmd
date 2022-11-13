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

module queryperf;

version (Windows)
{
    extern (Windows)
    {
        export int QueryPerformanceCounter(ulong *);
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
                mov   4[ECX],EDX        ;
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
                mov   4[RDI],EDX        ;
                ret                     ;
            }
        }
    }
}
else
{
    static assert(0);
}
