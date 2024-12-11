/*
TEST_OUTPUT:
---
fail_compilation/fail23.d(16): Error: `break` is not inside a loop or `switch`
        break;
        ^
---
*/

// ICE(s2ir.c) DMD0.100

void main()
{
    try
    {
        break;
    }
    catch (Throwable)
    {
    }
}
