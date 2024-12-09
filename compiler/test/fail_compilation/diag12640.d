/*
TEST_OUTPUT:
---
fail_compilation/diag12640.d(18): Error: undefined identifier `asdf`
            asdf;
            ^
fail_compilation/diag12640.d(27): Error: undefined identifier `asdf`
            asdf;
            ^
---
*/

void main()
{
    switch (1)
    {
        case 0:
            asdf;
            break;

        default:
    }

    switch (1)
    {
        default:
            asdf;
            break;

        case 0:
    }

}
