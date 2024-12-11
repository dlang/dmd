/*
TEST_OUTPUT:
---
fail_compilation/ice11726.d(18): Error: undefined identifier `x`
    S().reserve(x.foo());
                ^
---
*/

struct S
{
    auto opDispatch(string fn, Args...)(Args args)
    {
    }
}

void main() {
    S().reserve(x.foo());
}
