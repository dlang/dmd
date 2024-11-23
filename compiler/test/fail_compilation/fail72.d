/*
TEST_OUTPUT:
---
fail_compilation/fail72.d(12): Error: undefined identifier `foo`
    synchronized( foo )
                  ^
---
*/

void main()
{
    synchronized( foo )
    {

    }
}
