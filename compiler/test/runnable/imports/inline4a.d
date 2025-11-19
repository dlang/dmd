module imports.inline4a;

pragma(inline, true)
int foo()
{
    return 1;
}

pragma(inline, true)
auto bar()
{
    return &foo;
}
