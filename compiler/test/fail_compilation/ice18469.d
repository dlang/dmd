/*
TEST_OUTPUT:
---
fail_compilation/ice18469.d(12): Error: no property `opCall` for `this.~this()` of type `void`
    this(){alias T = typeof(Bar.__dtor.opCall);}
                                      ^
---
*/
class Bar
{
    ~this(){}
    this(){alias T = typeof(Bar.__dtor.opCall);}
}

void main() {}
