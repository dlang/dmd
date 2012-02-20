// REQUIRED_ARGS: -O

extern(C) int printf(const char *, ...);

long funca(long v)
{
    return v ? funca(v - 1) : 0;
}

long funcb(long v)
{
    if (v)
        return funcb(v - 1);
    else
        return 0;
}

void main()
{
    printf("%d\n", funca(100_000));
    printf("%d\n", funcb(100_000));
}
