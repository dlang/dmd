/*
TEST_OUTPUT:
---
fail_compilation/ice13220.d(22): Error: template instance `test!0` does not match template declaration `test(T)()`
fail_compilation/ice13220.d(22):        instantiated from here: `test!0`
fail_compilation/ice13220.d(14):        Candidate match: test(T)()
---
*/

#line 100

struct Tuple(T...)
{
    T field;
    alias field this;
}

template test(T)
{
    bool test() { return false; };
}

void main()
{
    Tuple!bool t;
    t[0] = test!0();
}
