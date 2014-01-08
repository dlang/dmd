/*
TEST_OUTPUT:
---
fail_compilation/fail70.d(17): Error: can only initialize const member z inside constructor
---
*/

const int z;

static this()
{
    z = 3;
}

int main()
{
    z = 4;

    return 0;
}

