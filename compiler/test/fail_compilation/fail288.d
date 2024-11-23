/*
TEST_OUTPUT:
---
fail_compilation/fail288.d(16): Error: case ranges not allowed in `final switch`
        case E.a: .. case E.b:
        ^
---
*/

void main()
{
    enum E { a, b }
    E i = E.a;
    final switch (i)
    {
        case E.a: .. case E.b:
            break;
    }
}
