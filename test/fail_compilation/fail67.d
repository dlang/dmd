/*
TEST_OUTPUT:
---
fail_compilation/fail67.d(22): Error: can only initialize const member y inside constructor
---
*/

class C
{
    const int y;

    this()
    {
        y = 7;
    }
}

int main()
{
    C c = new C();

    c.y = 3;

    return 0;
}

