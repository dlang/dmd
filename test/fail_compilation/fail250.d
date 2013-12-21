/*
TEST_OUTPUT:
---
fail_compilation/fail250.d(10): Error: constructor fail250.A.this default constructor for structs only allowed with @disable and no body
---
*/

struct A
{
    this() {}
}

void main()
{
    auto a = A();
}
