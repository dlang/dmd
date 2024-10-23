// LINK(windows):
// REQUIRED_ARGS: -os=windows
// PERMUTE_ARGS: -betterC -i
// Checking that the MSVC intrinsics reimplemented for ImportC are actually available from C.

#include <importc_msvc_builtins.h>

#ifndef __IMPORTC_MSVC_BUILTINS__
#error importc_msvc_builtins.h should define __IMPORTC_MSVC_BUILTINS__.
#endif

// It should be safe to include importc_msvc_builtins.h multiple times.
#include <importc_msvc_builtins.h>

// Are the MSVC intrinsics actually usable from C?
#if defined(_M_AMD64)
unsigned long long multiplyU128(unsigned long long a, unsigned long long b, unsigned long long* high)
{
    return _umul128(a, b, high);
}
#elif defined(_M_IX86)
int interlockedAddLarge(long long *target, int value)
{
    return _InterlockedAddLargeStatistic(target, value);
}
#elif defined(_M_ARM64)
unsigned long long multiplyUHigh64(unsigned long long a, unsigned long long b)
{
    return __umulh(a, b);
}
#elif defined(_M_ARM)
void dmb(void)
{
    __dmb(11);
}
#endif

// Just so the linker doesn't complain.
int main(void)
{
    return 0;
}
