/*
EXTRA_FILES: issue18967a.d
TEST_OUTPUT:
---
fail_compilation/issue18967.d(13): Error: cannot modify module `issue18967a`
---
*/
// https://github.com/dlang/dmd/issues/18967
import issue18967a;

void test()
{
    issue18967a = 42;
}
