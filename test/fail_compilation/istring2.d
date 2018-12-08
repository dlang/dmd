/*
PERMUTE_ARGS:
REQUIRED_ARGS: -transition=interpolate
TEST_OUTPUT:
---
fail_compilation/istring2.d(11): Error: undefined identifier `a`
---
*/
enum s1 = i`

    $(a)`;
