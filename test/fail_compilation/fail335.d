/*
TEST_OUTPUT:
---
fail_compilation/fail335.d(9): Error: cannot overload both property and non-property functions
---
*/

void foo() @system;
@property void foo(int) @system;

void main()
{
    foo(1);
}
