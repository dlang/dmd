/*
EXTRA_FILES: imports/constraints.d
TEST_OUTPUT:
---
fail_compilation/constraints_aggr.d(106): Error: template `f` is not callable using argument types `!()(int)`
fail_compilation/imports/constraints.d(60):        Candidate is: `f(T)(T v)`
  with `T = int`
  must satisfy the following constraint:
`       !P!T`
fail_compilation/constraints_aggr.d(107): Error: template `g` is not callable using argument types `!()()`
fail_compilation/imports/constraints.d(63):        Candidate is: `g(this T)()`
  with `T = imports.constraints.C`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_aggr.d(109): Error: template instance `imports.constraints.S!int` does not match template declaration `S(T)`
  with `T = int`
  must satisfy the following constraint:
`       N!T`
fail_compilation/constraints_aggr.d(109):        instantiated from here: `S!int`
fail_compilation/imports/constraints.d(67):        Candidate match: S(T) if (N!T)
fail_compilation/constraints_aggr.d(118): Error: template instance `imports.constraints.BitFlags!(Enum)` does not match template declaration `BitFlags(E, bool unsafe = false)`
  with `E = Enum`
  must satisfy one of the following constraints:
`       unsafe
       N!E`
fail_compilation/constraints_aggr.d(118):        instantiated from here: `BitFlags!(Enum)`
fail_compilation/imports/constraints.d(72):        Candidate match: BitFlags(E, bool unsafe = false) if (unsafe || N!E)
---
*/

#line 100

void main()
{
    import imports.constraints;

    C c = new C;
    c.f(0);
    c.g();

    S!int;

    enum Enum
    {
        A = 1,
        B = 2,
        C = 4,
        BC = B|C
    }
    BitFlags!Enum flags;
}
