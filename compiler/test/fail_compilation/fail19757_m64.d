// REQUIRED_ARGS: -m64
/*
TEST_OUTPUT:
---
fail_compilation/fail19757_m64.d(11): Error: cannot implicitly convert expression `"oops"` of type `string` to `ulong`
auto s = new string("oops");
                    ^
---
*/

auto s = new string("oops");
