/*
EXTRA_SOURCES: imports/issue18967a.d
TEST_OUTPUT:
---
fail_compilation/issue18967.d(12): Error: cannot modify module `issue18967a`
---
*/
// https://github.com/dlang/dmd/issues/18967
import imports.issue18967a;
void test()
{
    imports.issue18967a = 42;
}
