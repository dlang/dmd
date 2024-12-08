/*
REQUIRED_ARGS: -O
TEST_OUTPUT:
---
fail_compilation/fail5908.d(20): Error: divide by zero
    return (a % b) +
            ^
fail_compilation/fail5908.d(21): Error: divide by zero
        (a / b);
         ^
---
*/

// This bug is caught by the dmd optimizer - other backends might not catch it or give a different message

int main()
{
    int a = 1;
    int b = 0;
    return (a % b) +
        (a / b);
}
