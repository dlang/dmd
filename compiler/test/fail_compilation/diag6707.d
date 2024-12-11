/*
TEST_OUTPUT:
---
fail_compilation/diag6707.d(21): Error: mutable method `diag6707.Foo.value` is not callable using a `const` object
        auto x = value;
                 ^
fail_compilation/diag6707.d(17):        Consider adding `const` or `inout` here
    @property bool value() { return true; }
                   ^
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
