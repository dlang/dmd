// REQUIRED_ARGS: -d -m32
/*
TEST_OUTPUT:
---
fail_compilation/fail121.d(24): Error: .typeinfo deprecated, use typeid(type)
fail_compilation/fail121.d(24): Error: .typeinfo deprecated, use typeid(type)
fail_compilation/fail121.d(24): Error: list[1u].typeinfo is not an lvalue
---
*/
// segfault on DMD0.150, never failed if use typeid() instead.

struct myobject
{
    TypeInfo objecttype;
    void * offset;
}

myobject[] list;

void foo()
{
    int i;

    list[1u].typeinfo = i.typeinfo;
}
