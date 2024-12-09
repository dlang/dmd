/*
TEST_OUTPUT:
---
fail_compilation/ice11922.d(15): Error: undefined identifier `a`
    auto f(B)(B) { return a; }
                          ^
fail_compilation/ice11922.d(21): Error: template instance `ice11922.S.f!int` error instantiating
    s.f(5);
       ^
---
*/

struct S
{
    auto f(B)(B) { return a; }
}

void main()
{
    S s;
    s.f(5);
}
