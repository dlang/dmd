/*
TEST_OUTPUT:
---
fail_compilation/staticassertargs.d(11): Error: static assert:  abcxe3!!
static assert(false, "abc", ['x', 'e'], 3, e);
^
---
*/

enum e = "!!";
static assert(false, "abc", ['x', 'e'], 3, e);
