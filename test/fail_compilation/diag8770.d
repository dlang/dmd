/*
TEST_OUTPUT:
---
fail_compilation/diag8770.d(6): Error: this.f is not mutable
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
