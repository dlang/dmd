// An unreferenced __forceinline function must not generate code, even if
// its own body calls another __forceinline function that would otherwise
// also be unreferenced - a candidate counts as referenced only via code
// outside the set of __forceinline candidates.

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
