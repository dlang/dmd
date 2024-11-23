/*
TEST_OUTPUT:
---
fail_compilation/ice10382.d(16): Error: can only catch class objects, not `int`
    catch (int a) { }
    ^
---
*/

void main ()
{
    try
    {
        int b = 3;
    }
    catch (int a) { }
}
