/*
TEST_OUTPUT:
---
fail_compilation/fail289.d(14): Error: cannot cast from function pointer to delegate
    Dg d = cast(void delegate())&fun;
                                ^
---
*/

alias void delegate() Dg;
void fun() {}
void gun()
{
    Dg d = cast(void delegate())&fun;
}
