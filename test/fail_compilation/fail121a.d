// REQUIRED_ARGS: -d -m64
/*
TEST_OUTPUT:
---
fail_compilation/fail121a.d(24): Error: .typeinfo deprecated, use typeid(type)
fail_compilation/fail121a.d(24): Error: .typeinfo deprecated, use typeid(type)
fail_compilation/fail121a.d(24): Error: list[1LU].typeinfo is not an lvalue
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

    list[1LU].typeinfo = i.typeinfo;
}
