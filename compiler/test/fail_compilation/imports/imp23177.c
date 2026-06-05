// https://github.com/dlang/dmd/issues/23177

typedef int(*fp)();
int run1(fp fn)
{
    return fn();
}

int f(a)
int a;
{
    return a;
}
int run2(int (*fn)(int a))
{
    return fn(42);
}
