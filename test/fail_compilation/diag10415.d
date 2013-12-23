/*
TEST_OUTPUT:
---
fail_compilation/diag10415.d(34): Error: function diag10415.C.x () const is not callable using argument types (int) const
fail_compilation/diag10415.d(37): Error: d.x is not an lvalue
---
*/

class C
{
    @property int x() const
    {
        return 0;
    }

    @property void x(int)
    {
    }
}

template AddProp() { @property int x() { return 1; } }
template AddFunc() { void x(int, int) {} }

class D
{
    // overloadset
    mixin AddProp;
    mixin AddFunc;
}

void main()
{
    const c = new C();
    c.x = 1;

    auto d = new D();
    d.x = 1;
}
