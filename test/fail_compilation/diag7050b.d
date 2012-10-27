/*
TEST_OUTPUT:
---
fail_compilation/diag7050b.d(5): Error: pure function 'diag7050b.f.g' cannot call impure function 'diag7050b.f'
---
*/

#line 1
void f()
{
    pure void g()
    {
        f();
    }
}
