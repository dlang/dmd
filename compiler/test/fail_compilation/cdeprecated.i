/* REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/cdeprecated.i(26): Deprecation: function `cdeprecated.mars` is deprecated
        mars() +
            ^
fail_compilation/cdeprecated.i(27): Deprecation: function `cdeprecated.jupiter` is deprecated - jumping jupiter
        jupiter() +
               ^
fail_compilation/cdeprecated.i(28): Deprecation: function `cdeprecated.saturn` is deprecated
        saturn() +
              ^
fail_compilation/cdeprecated.i(29): Deprecation: function `cdeprecated.neptune` is deprecated - spinning neptune
        neptune();
               ^
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
