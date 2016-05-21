/*
TEST_OUTPUT:
---
fail_compilation/fail335.d(9): Error: cannot overload both property and non-property functions
fail_compilation/fail335.d(13): Error: is a property foo
---
*/
void foo();
@property void foo(int);

void main()
{
    foo(1);
}
