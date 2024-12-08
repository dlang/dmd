/* DISABLED: win32 linux32
TEST_OUTPUT:
---
fail_compilation/test23875.c(16): Error: __attribute__((vector_size(10))) must be an integer positive power of 2 and be <= 32,768
int __attribute__((vector_size(10))) neptune();
                               ^
fail_compilation/test23875.c(17): Error: value for vector_size expected, not `x`
int __attribute__((vector_size(x))) saturn();
                               ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=23875
// https://issues.dlang.org/show_bug.cgi?id=23880

int __attribute__((vector_size(10))) neptune();
int __attribute__((vector_size(x))) saturn();
