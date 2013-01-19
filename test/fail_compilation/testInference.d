/*
TEST_OUTPUT:
---
fail_compilation/testInference.d(24): Error: cannot implicitly convert expression (this.a) of type inout(A8998) to immutable(A8998)
---
*/

class A8998
{
    int i;
}
class C8998
{
    A8998 a;

    this()
    {
        a = new A8998();
    }

    // WRONG: Returns immutable(A8998)
    immutable(A8998) get() inout pure
    {
        return a;   // should be error
    }
}
