module imports.gdb22905c;

pragma(inline, false)
void funcC(T)(T param, void delegate() dg = null)
{
    return;
}

struct S
{
    void function() f;
    void *ptr;
}
