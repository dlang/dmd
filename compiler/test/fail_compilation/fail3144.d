/*
TEST_OUTPUT:
---
fail_compilation/fail3144.d(16): Error: `break` is not inside a loop or `switch`
        default: {} break;
                    ^
fail_compilation/fail3144.d(19): Error: `break` is not inside a loop or `switch`
        case 1: {} break;
                   ^
---
*/

void main()
{
    switch (1)
        default: {} break;

    final switch (1)
        case 1: {} break;
}
