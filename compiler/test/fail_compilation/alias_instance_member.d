/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/alias_instance_member.d(16): Deprecation: cannot alias member of variable `that`
fail_compilation/alias_instance_member.d(16):        Use `typeof(that)` instead to preserve behaviour
---
*/

struct Foo
{
    int v;
    void test(Foo that) const
    {
        alias a = this.v; // OK
        alias b = that.v;
        assert(&a is &b);
    }
}

void main()
{
    Foo a = Foo(1);
    Foo b = Foo(2);
    a.test(b);
}
