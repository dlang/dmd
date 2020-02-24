/*
TEST_OUTPUT:
---
tuple("object", "shared_ctor", "ctor", "Bar", "foobar", "main", "_d_run_main", "_Dmain")
fail_compilation/fail20607.d(153): Error: undefined identifier `_sharedStaticCtor_L102_C1`
fail_compilation/fail20607.d(154): Error: undefined identifier `_staticCtor_L108_C1`
fail_compilation/fail20607.d(155): Error: undefined identifier `_sharedStaticDtor_L115_C1`
fail_compilation/fail20607.d(156): Error: undefined identifier `_staticDtor_L119_C1`
fail_compilation/fail20607.d(157): Error: function expected before `()`, not `__unittest_L126_C1`
fail_compilation/fail20607.d(162): Error: no property `__invariant` for type `Bar`, did you mean `fail20607.Bar.__invariant1`?
---
*/

// This line statement is really important, since the name of the ctors/dtors
// and unittests depend on the line number
#line 100
// Ctors
immutable bool shared_ctor;
shared static this ()
{
    assert(!shared_ctor);
    shared_ctor = true;
}
__gshared bool ctor;
static this ()
{
    assert(shared_ctor);
    assert(!ctor);
    ctor = true;
}
// Dtors
shared static ~this ()
{
    assert(shared_ctor);
}
static ~this ()
{
    assert(shared_ctor);
    assert(ctor);
    ctor = false;
}

unittest // This shouldn't be visible
{
    int x;
    assert(x == 42);
}

struct Bar
{
    invariant() // Neither should this
    {
        assert(false);
    }
}

int foobar()
out
{
    assert(__result == 42); // Or this
}
do
{
    return 42;
}

void main ()
{
    pragma(msg, __traits(allMembers, mixin(__MODULE__)));
    _sharedStaticCtor_L102_C1();
    _staticCtor_L108_C1();
    _sharedStaticDtor_L115_C1();
    _staticDtor_L119_C1();
    __unittest_L126_C1();

    Bar b = Bar.init; // Bypass invariant
    b.__invariant1();
    // This should test that `impHint` does not know about hidden symbols
    b.__invariant();

    // Note: The following, along with the `out` contract test,
    // the invariant, and the unittest, should fail.
    // However this requires a more significant refactor.
    // This issue is also present in foreach (with temporaries),
    // and people might rely on it.
    _d_run_main(0, null, null);
    _Dmain(null);
}
