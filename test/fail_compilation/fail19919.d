// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail19919.d(17): Deprecation: union field `f` with default initialization `3.14F` must be before field `n`
fail_compilation/fail19919.d(24): Deprecation: union field `f` with default initialization `3.14F` must be before field `n`
---
*/

void main()
{
    struct X
    {
        union
        {
            int n;
            float f = 3.14f;
        }
    }

    union U
    {
        int n;
        float f = 3.14f;
    }
}
