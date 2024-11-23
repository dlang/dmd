/*
TEST_OUTPUT:
---
fail_compilation/ice12362.d(14): Error: initializer must be an expression, not `foo`
    enum bar = foo;
               ^
---
*/

enum foo;

void main()
{
    enum bar = foo;
}
