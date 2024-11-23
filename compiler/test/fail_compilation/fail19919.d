/*
TEST_OUTPUT:
---
fail_compilation/fail19919.d(20): Error: union field `f` with default initialization `3.14F` must be before field `n`
            float f = 3.14f;
                  ^
fail_compilation/fail19919.d(27): Error: union field `f` with default initialization `3.14F` must be before field `n`
        float f = 3.14f;
              ^
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
