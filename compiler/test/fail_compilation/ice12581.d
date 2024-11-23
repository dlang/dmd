/*
TEST_OUTPUT:
---
fail_compilation/ice12581.d(23): Error: undefined identifier `undef`
    x[] = (undef = 1);
           ^
---
*/

struct S
{
    int[3] a;
    alias a this;
}
struct T
{
    S s;
    alias s this;
}
void main()
{
    T x;
    x[] = (undef = 1);
}
