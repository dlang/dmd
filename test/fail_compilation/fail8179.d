/*
TEST_OUTPUT:
---
fail_compilation/fail8179.d(10): Error: cannot cast null to int[2]
---
*/
void main()
{
    int[2] a;
    a = cast(int[2])null;
}
