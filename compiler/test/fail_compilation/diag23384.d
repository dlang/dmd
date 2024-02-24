// https://issues.dlang.org/show_bug.cgi?id=23384

/*
TEST_OUTPUT:
---
fail_compilation/diag23384.d(29): Error: function `fun` is not callable using argument types `(A)`
fail_compilation/diag23384.d(29):        function `diag23384.Derived.fun` hides base class function `diag23384.Base.fun`
fail_compilation/diag23384.d(29):        add `alias fun = diag23384.Base.fun` to `diag23384.Derived`'s body to merge the overload sets
fail_compilation/diag23384.d(23):        `diag23384.Derived.fun(B b)` declared here
---
*/

struct A {}
struct B {}

class Base
{
    void fun(A a) {}
}

class Derived : Base
{
    void fun(B b) {}
}

void main()
{
    Derived d;
    d.fun(A());
}
