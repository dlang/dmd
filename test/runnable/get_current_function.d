module get_current_function;

void f1(int p)
{
    alias CF1 = typeof(__traits(getCurrentFunction));
    alias CF2 = void(int);
    static assert(is(CF1));
    static assert(is(CF1 == CF2));
}

int f1(string p)
{
    alias CF1 = typeof(__traits(getCurrentFunction));
    alias CF2 = int(string);
    static assert(is(CF1));
    static assert(is(CF1 == CF2));
    return 0;
}

struct S
{
    static assert(!is(typeof(__traits(getCurrentFunction))));
}

long fact1(long n) {
    if (n <= 1)
        return 1;
    else
        return n * __traits(getCurrentFunction)(n - 1);
}

void main()
{
    assert(fact1(20) == 2_432_902_008_176_640_000);
}
