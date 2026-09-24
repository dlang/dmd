/*
TEST_OUTPUT:
---
fail_compilation/enum_union_const_mutation.d(20): Error: cannot modify `const` expression `*p`
fail_compilation/enum_union_const_mutation.d(18): Error: switch expression has no effect; use `cast(void)` to discard its value
---
*/

enum union Value
{
    case Ptr(int*);
}

void main()
{
    int x = 42;
    const Value u = Value.Ptr(&x);

    switch (u)
    {
        case Ptr(p) => *p = 999,
    }
}
