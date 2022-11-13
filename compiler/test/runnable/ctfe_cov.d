//REQUIRED_ARGS: -cov=100 -cov=ctfe
int f(int n) { int acc;
    foreach(i;0 .. n)
    {
        acc += i;
    }
    return acc;
}


static assert(f2(4) == 6);
static assert(f(4) == 6);
static assert(f2(4) == 6);
static assert(f15() == 1);

void main()
{
    import core.stdc.stdio;
    printf("%d %d %d\n", f(1), f(2), f(3));
}

int f15()
{
    return 1;
}

int f2(int n)
{
    int acc;
    foreach(i;0 .. n)
    {
        acc += i;
    }
    return acc;}
