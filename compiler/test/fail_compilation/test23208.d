/*
REQUIRED_ARGS:-preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test23208.d(31): Error: returning `rsfailA(& i, null)` escapes a reference to local variable `i`
fail_compilation/test23208.d(32): Error: returning `rsfailB(& i, null)` escapes a reference to local variable `i`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23208
// Issue 23208 - [dip1000] missing return scope inference after parameter assignment

@safe:

int* rsfailA()(scope int* pA, int* rA)
{
    rA = pA;
    return rA; // should infer return scope on p
}

int* rsfailB()(int* pB, int* rB)
{
    rB = pB;
    return rB; // should infer return scope on p
}


int* escape()
{
    int i;
    return rsfailA(&i, null); // error
    return rsfailB(&i, null); // error
}
