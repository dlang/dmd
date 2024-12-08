/*
TEST_OUTPUT:
---
fail_compilation/diag13942.d(24): Error: template instance `isRawStaticArray!()` does not match template declaration `isRawStaticArray(T, A...)`
        if (!isRawStaticArray!A)
             ^
fail_compilation/diag13942.d(32): Error: template `to` is not callable using argument types `!()()`
    auto t = to!double();
                      ^
fail_compilation/diag13942.d(23):        Candidate is: `to(A...)(A args)`
    T to(A...)(A args)
      ^
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
