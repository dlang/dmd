/*
TEST_OUTPUT:
---
fail_compilation/fail256.d(10): Error: incompatible types for `("foo"d) ~ ("bar"c)`: `dstring` and `string`
auto s = "foo"d ~ "bar"c;
         ^
---
*/

auto s = "foo"d ~ "bar"c;
