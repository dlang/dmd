/*
TEST_OUTPUT:
---
fail_compilation/class1.d(13): Error: class `class1.C` identity assignment operator overload is illegal
    void opAssign(C rhs){}
         ^
---
*/

class C
{
    // Non-templated identity opAssign
    void opAssign(C rhs){}
}
