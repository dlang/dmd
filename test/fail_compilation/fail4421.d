/*
TEST_OUTPUT:
---
fail_compilation/fail4421.d(16): Error: function fail4421.U1.__postblit destructors, postblits and invariants are not allowed in union U1
fail_compilation/fail4421.d(17): Error: destructor fail4421.U1.~this destructors, postblits and invariants are not allowed in union U1
fail_compilation/fail4421.d(18): Error: function fail4421.U1.__invariant1 destructors, postblits and invariants are not allowed in union U1
fail_compilation/fail4421.d(14): Error: function fail4421.U1.__invariant destructors, postblits and invariants are not allowed in union U1
fail_compilation/fail4421.d(28): Error: destructor fail4421.U2.~this destructors, postblits and invariants are not allowed in union U2
fail_compilation/fail4421.d(28): Error: function fail4421.U2.__fieldPostBlit destructors, postblits and invariants are not allowed in union U2
fail_compilation/fail4421.d(33): Error: struct fail4421.S2 destructors, postblits and invariants are not allowed in overlapping fields s1 and j
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

