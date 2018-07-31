/*
TEST_OUTPUT:
---
fail_compilation/diag6707.d(17): Error: mutable method `diag6707.Foo.value` is not callable using a `const` object
fail_compilation/diag6707.d(17):        Consider adding `const` or `inout` to diag6707.Foo.value
---
*/

module diag6707;

struct Foo
{
    @property bool value() { return true; }

    void test() const
    {
        auto x = value;
    }
}
