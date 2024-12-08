/*
TEST_OUTPUT:
---
fail_compilation/diag15186.d(18): Error: use `.` for member lookup, not `::`
    S::x = 1;
       ^
fail_compilation/diag15186.d(19): Error: use `.` for member lookup, not `->`
    s->y = 2;
       ^
---
*/

void main()
{
    struct S { static int x; int y; }
    S* s;

    S::x = 1;
    s->y = 2;
}
