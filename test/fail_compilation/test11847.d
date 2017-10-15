/*
REQUIRED_ARGS: -Ifail_compilation/imports -de
EXTRA_SOURCES: extra-files/extra11847.d
TEST_OUTPUT:
----
fail_compilation/test11847.d(13): Deprecation: module pkg11847.mod is not accessible here, perhaps add 'static import pkg11847.mod;'
----
 */
import pkg11847;

void test()
{
    auto a = pkg11847.mod.sym;
}
