/*
TEST_OUTPUT:
---
fail_compilation/ice13921.d(17): Error: undefined identifier `undefined_identifier`
        undefined_identifier;
        ^
fail_compilation/ice13921.d(29): Error: template instance `ice13921.S!string` error instantiating
    S!string g;
    ^
---
*/

struct S(N)
{
    void fun()
    {
        undefined_identifier;
        // or anything that makes the instantiation fail
    }

}

void test(T)(S!T)
{
}

void main()
{
    S!string g;
    test(g);
}
