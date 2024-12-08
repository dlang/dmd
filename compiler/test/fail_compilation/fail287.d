/*
TEST_OUTPUT:
---
fail_compilation/fail287.d(16): Error: had 300 cases which is more than 257 cases in case range
        case 1: .. case 300:
        ^
---
*/


void main()
{
    int i = 2;
    switch (i)
    {
        case 1: .. case 300:
            i = 5;
            break;
    }
    if (i != 5)
        assert(0);
}
