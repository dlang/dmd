// REQUIRED_ARGS: -d
/*
TEST_OUTPUT:
---
fail_compilation/fail138.d(14): Error: void initializer has no value
---
*/

typedef int T = void;

void main()
{
    T x = void;
    x = x.init;
}

