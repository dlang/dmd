/* REQUIRED_ARGS: -main -de
 * TEST_OUTPUT:
---
fail_compilation/test11006.d(18): Deprecation: cannot subtract pointers to different types: `void*` and `int*`.
static assert(cast(void*)8 - cast(int*) 0 == 2L);
              ^
fail_compilation/test11006.d(18):        while evaluating: `static assert(2L == 2L)`
static assert(cast(void*)8 - cast(int*) 0 == 2L);
^
fail_compilation/test11006.d(19): Deprecation: cannot subtract pointers to different types: `int*` and `void*`.
static assert(cast(int*) 8 - cast(void*)0 == 8L);
              ^
fail_compilation/test11006.d(19):        while evaluating: `static assert(8L == 8L)`
static assert(cast(int*) 8 - cast(void*)0 == 8L);
^
---
 */
static assert(cast(void*)8 - cast(int*) 0 == 2L);
static assert(cast(int*) 8 - cast(void*)0 == 8L);
