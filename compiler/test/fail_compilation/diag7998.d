/*
TEST_OUTPUT:
---
fail_compilation/diag7998.d(12): Error: static assert:  "abcxe"
static assert(false, "abc" ~['x'] ~ "e");
^
---
*/

module diag7998;

static assert(false, "abc" ~['x'] ~ "e");
