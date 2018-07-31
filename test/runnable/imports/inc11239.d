// REQUIRED_ARGS:

int foo(T)(T x)
{
    return 3;
}

debug
{
    int x = foo(2);
}
