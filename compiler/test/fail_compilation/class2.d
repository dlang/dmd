/*
TEST_OUTPUT:
---
fail_compilation/class2.d(13): Error: class `class2.C` identity assignment operator overload is illegal
    void opAssign(T)(T rhs){}
         ^
---
*/

class C
{
    // Templated identity opAssign
    void opAssign(T)(T rhs){}
}
