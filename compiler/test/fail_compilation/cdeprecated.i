/* REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/cdeprecated.i(22): Deprecation: function `cdeprecated.mars` is deprecated
fail_compilation/cdeprecated.i(14):        `mars` is declared here
fail_compilation/cdeprecated.i(23): Deprecation: function `cdeprecated.jupiter` is deprecated - jumping jupiter
fail_compilation/cdeprecated.i(15):        `jupiter` is declared here
fail_compilation/cdeprecated.i(24): Deprecation: function `cdeprecated.saturn` is deprecated
fail_compilation/cdeprecated.i(16):        `saturn` is declared here
fail_compilation/cdeprecated.i(25): Deprecation: function `cdeprecated.neptune` is deprecated - spinning neptune
fail_compilation/cdeprecated.i(17):        `neptune` is declared here
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
