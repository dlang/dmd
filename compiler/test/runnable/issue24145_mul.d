// REQUIRED_ARGS: -O
// PERMUTE_ARGS:

// Preserve an earlier operand when multiplication overwrites its register.
pragma(inline, false)
int multiplyRuntime(int a, int b)
{
    auto x = a;
    return (x = a + b) + (x *= b) + (a + b);
}

// Exercise the generic immediate-multiplication path as well.
pragma(inline, false)
int multiplyConstant(int a, int b)
{
    auto x = a;
    return (x = a + b) + (x *= 7) + (a + b);
}

void main()
{
    assert(multiplyRuntime(25, 6) == 248);
    assert(multiplyConstant(25, 6) == 279);
}
