// REQUIRED_ARGS:
/*
TEST_OUTPUT:
---
fail_compilation/fail11653.d(18): Error: switch case fallthrough - use 'goto case;' if intended
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
        default:
            output = 3;
    }
}
