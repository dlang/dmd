/*
TEST_OUTPUT:
---
fail_compilation/diag8928.d(10): Error: class diag8928.Z Cannot implicitly generate a default ctor when base class diag8928.X is missing a default ctor
---
*/

#line 1
class X {
   this(int n) {}
}

class Y : X
{
    this() { }
}

class Z : X
{
}
