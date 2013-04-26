/*
TEST_OUTPUT:
---
fail_compilation/parseStc.d(10): Error: if (v; e) is deprecated, use if (auto v = e)
fail_compilation/parseStc.d(11): Error: redundant storage class 'const'
---
*/
void test1()
{
    if (x; 1) {}
    if (const const auto x = 1) {}
}
