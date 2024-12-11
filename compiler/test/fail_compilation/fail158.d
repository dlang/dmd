/*
TEST_OUTPUT:
---
fail_compilation/fail158.d(19): Error: too many initializers for `S` with 2 fields
    S s = S( 1, 5, 6 );
                   ^
---
*/

struct S
{
    int i;
    int j = 3;
}


void main()
{
    S s = S( 1, 5, 6 );
}
