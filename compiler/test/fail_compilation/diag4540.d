/*
TEST_OUTPUT:
---
fail_compilation/diag4540.d(13): Error: `x` must be of integral or string type, it is a `float`
    switch (x)
    ^
---
*/

void main()
{
    float x;
    switch (x)
    {
        default:
    }
}
