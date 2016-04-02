// REQUIRED_ARGS: -Wno-fallthrough -w
/*
TEST_OUTPUT:
---
fail_compilation/warn_fallthrough.d(21): Warning: switch case fallthrough - use 'goto default;' if intended (-Wfallthrough)
---
*/

void main()
{
    int test = 12412;
    int output = 0;
    switch(test)
    {
        case 1:
            output = 1;
            break;
        case 2: .. case 3:
            output = 2;
            //break; //Oops..
        default:
            output = 3;
    }
}
