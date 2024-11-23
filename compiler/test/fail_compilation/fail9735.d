/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/fail9735.d(12): Deprecation: casting from void delegate() to void* is deprecated
    return cast(void*) dg;
                       ^
---
*/

void* dg2ptr(void delegate() dg) {
    return cast(void*) dg;
}
