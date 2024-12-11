/*
TEST_OUTPUT:
---
fail_compilation/ice10341.d(12): Error: case range not in `switch` statement
    case 1: .. case 2:
    ^
---
*/

void main()
{
    case 1: .. case 2:
}
