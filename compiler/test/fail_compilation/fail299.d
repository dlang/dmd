/*
TEST_OUTPUT:
---
fail_compilation/fail299.d(16): Error: initializer provided for struct `Foo` with no fields
    foo(Foo(1), (){});
            ^
---
*/

struct Foo {}

void foo (Foo b, void delegate ()) {}

void main ()
{
    foo(Foo(1), (){});
}
