/*
TEST_OUTPUT:
---
fail_compilation/diag13320.d(15): Error: `f` is not a scalar, it is a `Foo`
    ++f;
      ^
---
*/

struct Foo {}

void main()
{
    Foo f;
    ++f;
}
