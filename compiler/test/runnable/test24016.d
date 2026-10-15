// https://github.com/dlang/dmd/issues/24016
// `is` on dynamic arrays compares .ptr and .length in CTFE, as it does at runtime

bool differentLiterals()
{
    int[] a = [1];
    int[] b = [1];
    return a is b;
}

bool sameNaN()
{
    double[] a = [double.nan];
    return a is a;
}

bool slices()
{
    int[] a = [1, 2, 3, 4];
    int[] b = a;
    assert(a is b);
    assert(a !is a.dup);
    assert(a[1 .. 3] is b[1 .. 3]);
    assert(a[1 .. 3] !is a[1 .. 2]);
    assert(a[1 .. 2] !is a[2 .. 3]);
    assert(a[0 .. 0] !is a[1 .. 1]);
    assert(a !is null);

    char[] s = "ab".dup;
    char[] t = s;
    assert(s is t);
    assert(s !is s.dup);

    int[] n1, n2;
    assert(n1 is n2);
    assert(n1 is null);
    return true;
}

static assert(!differentLiterals());
static assert(sameNaN());
static assert(slices());

void main()
{
    assert(!differentLiterals());
    assert(sameNaN());
    assert(slices());
}
