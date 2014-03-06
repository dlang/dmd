/*
TEST_OUTPUT:
---
fail_compilation/diag4540.d(4): Error: 'x' must be of integral or string type, it is a float
---
*/

#line 1
void main()
{
    float x;
    switch (x)
    {
        default:
    }
}
