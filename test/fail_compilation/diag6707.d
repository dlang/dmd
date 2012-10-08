/*
TEST_OUTPUT:
---
fail_compilation/diag6707.d(9): Error: function diag6707.Foo.value () is not callable using argument types () const
---
*/

#line 1
module diag6707;

struct Foo
{
    @property bool value() { return true; }

    void test() const
    {
        auto x = value;
    }
}
