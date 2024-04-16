/* REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/cdeprecated.i(18): Deprecation: function `cdeprecated.mars` is deprecated
fail_compilation/cdeprecated.i(19): Deprecation: function `cdeprecated.jupiter` is deprecated - jumping jupiter
fail_compilation/cdeprecated.i(20): Deprecation: function `cdeprecated.saturn` is deprecated
fail_compilation/cdeprecated.i(21): Deprecation: function `cdeprecated.neptune` is deprecated - spinning neptune
---
*/
__declspec(deprecated) int mars();
__declspec(deprecated("jumping jupiter")) int jupiter();
__attribute__((deprecated)) extern int saturn();
__attribute__((deprecated("spinning neptune"))) extern int neptune();

int test()
{
    return
        mars() +
        jupiter() +
        saturn() +
        neptune();
}
