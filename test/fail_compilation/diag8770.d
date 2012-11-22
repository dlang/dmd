/*
TEST_OUTPUT:
---
fail_compilation/diag8770.d(6): Error: cannot modify immutable field f, because it is already initialized
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
