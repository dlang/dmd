/*
TEST_OUTPUT:
---
fail_compilation/failoffset.d(11): Error: no property 'offset' for type 'int'
---
*/

void main()
{
    struct S { int a, b; }
    static assert(S.b.offset == 4);
}
