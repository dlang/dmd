/*
TEST_OUTPUT:
---
fail_compilation/diag8928.d(7): Error: constructor diag8928.Y.this no match for implicit super() call in constructor
fail_compilation/diag8928.d(10): Error: constructor diag8928.Z.this no match for implicit super() call in implicitly generated constructor
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
