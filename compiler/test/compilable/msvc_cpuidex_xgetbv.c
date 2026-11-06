// __cpuid/__cpuidex (druntime/src/__builtins_msvc.d) took `int[4]*`, but MSVC's own
// documented prototype (`int cpuInfo[4]`) decays to a plain pointer, which is what
// real C callers pass (e.g. sljit's `__cpuidex((int*)info, ...)`). _xgetbv was
// missing entirely, needed by the same kind of CPU feature detection code.

#if defined(_WIN32) && (defined(_M_X64) || defined(_M_IX86))

#include <importc_msvc_builtins.h>

int check_cpuidex(int *info)
{
    __cpuidex(info, 0, 0);
    return (int) _xgetbv(0);
}

#endif
