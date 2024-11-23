/*
TEST_OUTPUT:
---
fail_compilation/fail11653.d(22): Error: switch case fallthrough - use 'goto case;' if intended
        case 2: .. case 3:
        ^
fail_compilation/fail11653.d(27): Error: switch case fallthrough - use 'goto default;' if intended
        default:
        ^
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
            //break; //Oops..
        case 2: .. case 3:
            output = 2;
            break;
        case 4:
            output = 3;
        default:
            output = 4;
    }
}
