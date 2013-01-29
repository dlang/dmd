/*
TEST_OUTPUT:
---
fail_compilation/diag8770.d(3): Error: cannot modify immutable expression 1
fail_compilation/diag8770.d(6): Error: constant this.f is not an lvalue
---
*/

#line 1
class Foo
{
    immutable f = 1;
    this()
    {
        this.f = 1;
    }
}

void main() {}
