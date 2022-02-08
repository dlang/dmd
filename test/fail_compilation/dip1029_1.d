/*
TEST_OUTPUT:
---
fail_compilation/dip1029_1.d(101): Error: redundant attribute `throw`
fail_compilation/dip1029_1.d(102): Error: conflicting attribute `nothrow`
---
 */

#line 100

void tt() throw throw;
void tn() throw nothrow;

