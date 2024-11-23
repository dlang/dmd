/*
TEST_OUTPUT:
---
fail_compilation/diag10415.d(44): Error: none of the overloads of `x` are callable using argument types `(int) const`
    c.x = 1;
    ^
fail_compilation/diag10415.d(21):        Candidates are: `diag10415.C.x() const`
    @property int x() const
                  ^
fail_compilation/diag10415.d(26):                        `diag10415.C.x(int __param_0)`
    @property void x(int)
                   ^
fail_compilation/diag10415.d(47): Error: d.x is not an lvalue
    d.x = 1;
    ^
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
