/*
TEST_OUTPUT:
---
fail_compilation/fail5770.d(13): Error: struct imports.a5770.S member this is not accessible from module fail5770
fail_compilation/fail5770.d(14): Error: struct imports.a5770.S member this is not accessible from module fail5770
---
*/

import imports.a5770;

void main()
{
    auto s = S(10);
    auto t = S("a");
}
