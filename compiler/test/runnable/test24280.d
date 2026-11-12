// https://github.com/dlang/dmd/issues/24280

int call(alias fun)() { return fun(); }

int test(bool b)
{
    if (b)
    {
        int f() { return 1; }
        return call!f();
    }
    else
    {
        int f() { return 2; }
        return call!f();
    }
}

void main()
{
    assert(test(true) == 1);
    assert(test(false) == 2);
}
