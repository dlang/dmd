/*
TEST_OUTPUT:
---
fail_compilation/diag6707.d(18): Error: mutable method `value` is not callable using a `const` object
fail_compilation/diag6707.d(14):        `diag6707.Foo.value()` declared here
fail_compilation/diag6707.d(14):        Consider adding `const` or `inout`
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
