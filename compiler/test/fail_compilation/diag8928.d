/*
TEST_OUTPUT:
---
fail_compilation/diag8928.d(20): Error: class `diag8928.Z` cannot implicitly generate a default constructor when base class `diag8928.X` is missing a default constructor
class Z : X
^
---
*/

class X
{
    this(int n) {}
}

class Y : X
{
    this() {}
}

class Z : X
{
}
