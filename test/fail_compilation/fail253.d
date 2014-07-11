/*
TEST_OUTPUT:
---
fail_compilation/fail253.d(15): Error: cannot modify inout expression x
---
*/

void main()
{
    foreach (i; 0 .. 2)
    {
        foreach (inout char x; "hola")
        {
            //printf("%c", x);
            x = '?';
        }
    }
}
