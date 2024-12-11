/*
TEST_OUTPUT:
---
fail_compilation/diag8178.d(16): Error: cannot modify manifest constant `s`
    Foo.s = "";
    ^
---
*/

struct Foo
{
    enum string s = "";
}
void main()
{
    Foo.s = "";
}
