/*
REQUIRED_ARGS: -O
TEST_OUTPUT:
---
fail_compilation/fail5908.d(16): Error: divide by zero
fail_compilation/fail5908.d(17): Error: divide by zero
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
