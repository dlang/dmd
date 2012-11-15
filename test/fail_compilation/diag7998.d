/*
TEST_OUTPUT:
---
fail_compilation/diag7998.d(3): Error: static assert  "abcxe"
---
*/

#line 1
module diag7998;

static assert(false, "abc" ~['x'] ~ "e");
