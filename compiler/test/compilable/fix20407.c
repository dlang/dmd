// https://github.com/dlang/dmd/issues/20407

int f(int x)
{
    switch (x)
    {
        case 0: return 1;
        case 1: return 2;
        default: __builtin_unreachable();
    }
}

int g(int x)
{
    if (x)
        return 3;
    __builtin_unreachable();
}
