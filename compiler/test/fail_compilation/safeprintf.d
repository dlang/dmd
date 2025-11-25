/*
TEST_OUTPUT:
---
fail_compilation/safeprintf.d(14): Error: `@safe` function `safeprintf.func` cannot call `@system` function `safeprintf.printf`
fail_compilation/safeprintf.d(9):        `safeprintf.printf` is declared here
---
*/

extern (C) @system pragma(printf) int printf(const(char)* format, ...);

@safe void func(int i, char* s)
{
    printf("i: %d\n", i);
    printf("s: %s\n", s);
}
