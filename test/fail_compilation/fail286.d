/*
TEST_OUTPUT:
---
fail_compilation/fail286.d(16): Error: enum member B not represented in final switch
---
*/

enum E
{
    A,B,C
}

void main()
{
    E e;
    final switch (e)
    {
        case E.A:
//      case E.B:
        case E.C:
            ;
    }
}
