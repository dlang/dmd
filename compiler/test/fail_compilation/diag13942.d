/*
TEST_OUTPUT:
---
fail_compilation/diag13942.d(18): Error: template instance `isRawStaticArray!()` does not match template declaration `isRawStaticArray(T, A...)`
fail_compilation/diag13942.d(18):        instantiated from here: `isRawStaticArray!()`
fail_compilation/diag13942.d(10):        Candidate match: isRawStaticArray(T, A...)
fail_compilation/diag13942.d(26): Error: template `to` is not callable using argument types `!()()`
fail_compilation/diag13942.d(17):        Candidate is: `to(A...)(A args)`
---
*/

#line 100

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
