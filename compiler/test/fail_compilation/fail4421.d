/*
TEST_OUTPUT:
---
fail_compilation/fail4421.d(22): Error: function `fail4421.U1.__postblit` destructors, postblits and invariants are not allowed in union `U1`
    this(this);
    ^
fail_compilation/fail4421.d(23): Error: destructor `fail4421.U1.~this` destructors, postblits and invariants are not allowed in union `U1`
    ~this();
    ^
fail_compilation/fail4421.d(24): Error: function `fail4421.U1.__invariant1` destructors, postblits and invariants are not allowed in union `U1`
    invariant() { }
    ^
---




*/

union U1
{
    this(this);
    ~this();
    invariant() { }
}

struct S1
{
    this(this);
    ~this();
    invariant() { }
}

union U2
{
    S1 s1;
}

struct S2
{
    union
    {
        S1 s1;
        int j;
    }
}
