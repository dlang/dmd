module imports.test5309;

class FooBar
{
    int i;
}

__gshared int global = 84;

int foo (FooBar f)
{
    assert(f is null);
    return 42;
}
