/*
TEST_OUTPUT:
---
fail_compilation/noobject1.d(11): Error: undefined identifier `size_t`
---
*/

@noobject
module _none;

size_t foo();
