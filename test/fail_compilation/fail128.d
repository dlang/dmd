/*
TEST_OUTPUT:
---
fail_compilation/fail128.d(8): Error: arithmetic/string type expected for value-parameter, not void*
---
*/

template T(void *p) {}
