// https://issues.dlang.org/show_bug.cgi?id=76
// Using a non-template struct as a template
// Compiling leads to "Assertion failure: 's->parent' on line 1694 in file
// 'template.c'"
/*
TEST_OUTPUT:
---
fail_compilation/fail104.d(32): Error: template instance `P!()` `P` is not a template declaration, it is a alias
    mixin P!().T!();
          ^
fail_compilation/fail104.d(32): Error: mixin `fail104.C!(S).C.T!()` is not defined
    mixin P!().T!();
    ^
fail_compilation/fail104.d(37): Error: template instance `fail104.C!(S)` error instantiating
    auto c = new C!(S);
                 ^
---
*/

struct S
{
    template T()
    {
        void x(int i)
        {
        }
    }
}

class C(P)
{
    mixin P!().T!();
}

int main(char[][] args)
{
    auto c = new C!(S);

    return 0;
}
