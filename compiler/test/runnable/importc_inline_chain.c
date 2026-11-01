// A __forceinline function's own body must not count as evidence that
// something it calls is referenced, unless the function doing the calling
// is itself reachable from outside the set of __forceinline candidates -
// otherwise one never-called __forceinline function can keep another
// never-called __forceinline function alive just by mentioning it, as
// happened with real windows.h's RtlZeroVolatileMemory calling
// RtlFillVolatileMemory, neither of which anything else ever calls.

int undefined_elsewhere(void);

__forceinline int never_called_callee(void)
{
    return undefined_elsewhere();
}

__forceinline int never_called_caller(void)
{
    return never_called_callee();
}

// A real, reachable chain of __forceinline functions must still get code.

int helper(int x);

__forceinline int middle(int x)
{
    return helper(x) + 1;
}

__forceinline int entry(int x)
{
    return middle(x) + 1;
}

int helper(int x)
{
    return x * 2;
}

int main()
{
    if (entry(5) != 12)
        return 1;
    return 0;
}
