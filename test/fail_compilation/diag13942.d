/*
TEST_OUTPUT:
---
fail_compilation/diag13942.d(18): Error: template instance isRawStaticArray!() does not match template declaration isRawStaticArray(T, A...)
fail_compilation/diag13942.d(26): Error: template diag13942.to cannot deduce function from argument types !(double)(), candidates are:
fail_compilation/diag13942.d(15):        diag13942.to(T)
---
*/

template isRawStaticArray(T, A...)
{
    enum isRawStaticArray = false;
}

template to(T)
{
    T to(A...)(A args)
        if (!isRawStaticArray!A)
    {
        return 0;
    }
}

void main(string[] args)
{
    auto t = to!double();
}
