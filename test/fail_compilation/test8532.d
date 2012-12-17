/*
TEST_OUTPUT:
---
fail_compilation/test8532.d(13): Error: forward reference of return type deduction segfault8532
---
*/


/**************************************************
    8532    segfault(mtype.c) - type inference + pure
**************************************************/
auto segfault8532(Y, R ...)(R r, Y val) pure
{ return segfault8532(r, val); }

static assert(!is(typeof( segfault8532(1,2,3))));
