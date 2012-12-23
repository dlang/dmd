/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/diag6373.d(7): Deprecation: class diag6373.Bar use of diag6373.Foo.method(double x) hidden by Bar is deprecated. Use 'alias Foo.method method;' to introduce base class overload set.
---
*/

#line 1
class Foo
{
    void method(int x) { }
    void method(double x) { }
}

class Bar : Foo
{
    override void method(int x) { }
}

void main() { }
