// PERMUTE_ARGS: -d -dw
// segfault on DMD0.150, never failed if use typeid() instead.
/*
TEST_OUTPUT:
---
fail_compilation/fail121.d(30): Error: no property `typeinfo` for `list[1]` of type `fail121.myobject`
    list[1].typeinfo = i.typeinfo;
           ^
fail_compilation/fail121.d(18):        struct `myobject` defined here
struct myobject
^
fail_compilation/fail121.d(30): Error: no property `typeinfo` for `i` of type `int`
    list[1].typeinfo = i.typeinfo;
                        ^
---
*/

struct myobject
{
    TypeInfo objecttype;
    void* offset;
}

myobject[] list;

void foo()
{
    int i;

    list[1].typeinfo = i.typeinfo;
}
