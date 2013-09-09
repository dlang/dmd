/*
TEST_OUTPUT:
---
fail_compilation/fail340.d(17): Error: variable fail340.w of type struct const(CopyTest) uses this(this), which is not allowed in static initialization
---
*/

struct CopyTest
{
    double x;
    this(double a) { x = a * 10.0;}
    this(this) { x += 2.0; }
}

const CopyTest z = CopyTest(5.3);

const CopyTest w = z;
static assert(w.x == 55.0);
