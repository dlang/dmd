/*
TEST_OUTPUT:
---
fail_compilation/fail340.d(22): Error: variable `fail340.w` of type struct `const(CopyTest)` uses `this(this)`, which is not allowed in static initialization
const CopyTest w = z;
               ^
fail_compilation/fail340.d(23):        while evaluating: `static assert(w.x == 55.0)`
static assert(w.x == 55.0);
^
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
