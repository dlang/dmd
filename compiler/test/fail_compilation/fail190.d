/*
TEST_OUTPUT:
---
fail_compilation/fail190.d(13): Error: cannot have pointer to `(int, int, int)`
T* f(T...)(T x)
   ^
fail_compilation/fail190.d(20): Error: template instance `fail190.f!(int, int, int)` error instantiating
    auto x = f(2,3,4);
              ^
---
*/

T* f(T...)(T x)
{
    return null;
}

void main()
{
    auto x = f(2,3,4);
    *x = *x;
}
