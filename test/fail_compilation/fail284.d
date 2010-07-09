static int nasty;
int impure_evil_function(int x)
{
    nasty++;
    return nasty;
}

pure int foo(int x)
{
    int function(int) a = &impure_evil_function;
    return a(x);
}

