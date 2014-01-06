/*
TEST_OUTPUT:
---
fail_compilation/fail6453.d(14): Error: struct fail6453.S6453x mixing invariants with shared is not supported
fail_compilation/fail6453.d(19): Error: function fail6453.C6453y.__invariant4 synchronized can only be applied to class declarations
fail_compilation/fail6453.d(24): Error: function fail6453.C6453z.__invariant6 synchronized can only be applied to class declarations
fail_compilation/fail6453.d(24): Error: class fail6453.C6453z mixing invariants with shared is not supported
---
*/

struct S6453x
{
           invariant() {}
    shared invariant() {}
}
class C6453y
{
           invariant() {}
    synchronized invariant() {}
}
class C6453z
{
          shared invariant() {}
    synchronized invariant() {}
}
