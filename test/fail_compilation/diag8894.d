/*
TEST_OUTPUT:
---
fail_compilation/diag8894.d(6): Error: no property 'x' for type 'Foo'
fail_compilation/diag8894.d(7): Error: no property 'y' for type 'Foo'
fail_compilation/diag8894.d(8): Error: no property 'x' for type 'Foo'
fail_compilation/diag8894.d(9): Error: no property 'x' for type 'Foo'
---
*/

#line 1
struct Foo { }

void main()
{
    Foo f;
    f.x;           // UFCS getter1
    f.y!int;       // UFCS getter2
    f.x     = 10;  // UFCS setter1
    f.x!int = 10;  // UFCS setter2
}
