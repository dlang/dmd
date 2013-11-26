/*
TEST_OUTPUT:
---
fail_compilation/fail237.d(10): Error: undefined identifier 'a'
---
*/

// Issue 581 - Error message w/o line number in dot-instantiated template

static assert(.a!().b);
