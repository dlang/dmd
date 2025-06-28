// https://github.com/dlang/dmd/issues/21244
// This used to segfault the compiler. The below error message can change.
/*
* TEST_OUTPUT:
---
fail_compilation/test21244.c(9): Error: no size for type `extern (C) int(int)`
---
 */
int x = sizeof(int()(int));
