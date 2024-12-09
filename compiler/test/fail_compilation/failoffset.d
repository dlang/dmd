/*
TEST_OUTPUT:
---
fail_compilation/failoffset.d(16): Error: no property `offset` for `b` of type `int`
    static assert(S.b.offset == 4);
                     ^
fail_compilation/failoffset.d(16):        while evaluating: `static assert(b.offset == 4)`
    static assert(S.b.offset == 4);
    ^
---
*/

void main()
{
    struct S { int a, b; }
    static assert(S.b.offset == 4);
}
