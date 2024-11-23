/*
TEST_OUTPUT:
---
fail_compilation/ice8499.d(20): Error: undefined identifier `i`
    (Variant()).get!(typeof(() => i));
                                  ^
---
*/

struct Variant
{
    @property T get(T)()
    {
        struct X {}   // necessary
    }
}

void main()
{
    (Variant()).get!(typeof(() => i));
}
