/*
TEST_OUTPUT:
---
fail_compilation/ice13644.d(24): Error: foreach: key cannot be of non-integral type `string`
    foreach (string k2, string v2; foo())
    ^
---
*/

struct Tuple(T...)
{
    T field;
    alias field this;
}

Tuple!(string, string)[] foo()
{
    Tuple!(string, string)[] res;
    return res;
}

void main()
{
    foreach (string k2, string v2; foo())
    {
    }
}
