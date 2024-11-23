/*
TEST_OUTPUT:
---
fail_compilation/noreturn_expr2.d(10): Error: cannot cast `noreturn` to `int` at compile time
enum E {e1 = 1, e2 = 2, illegal = noreturn}
                                  ^
---
*/

enum E {e1 = 1, e2 = 2, illegal = noreturn}

void main()
{
    E e;
    e = E.illegal;
}
