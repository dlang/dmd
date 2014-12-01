/*
TEST_OUTPUT:
---
fail_compilation/ice12362.d(9): Error: enum ice12362.foo is forward referenced looking for base type
fail_compilation/ice12362.d(12): Error: cannot interpret foo at compile time
---
*/

enum foo;
void main()
{
    enum bar = foo;
}
