/*
DISABLED: win32 win64 freebsd32 openbsd32 linux32 osx32
TEST_OUTPUT:
---
fail_compilation/safeprintf.d(29): Error: calling `pragma(printf)` function `safeprintf.printf` with format string `"s: %s\n"` is not `@safe`
fail_compilation/safeprintf.d(21):        `safeprintf.printf` is declared here
fail_compilation/safeprintf.d(30): Error: calling `pragma(printf)` function `safeprintf.printf` with format string `"s: %S\n"` is not `@safe`
fail_compilation/safeprintf.d(21):        `safeprintf.printf` is declared here
fail_compilation/safeprintf.d(31): Error: calling `pragma(printf)` function `safeprintf.printf` with format string `"s: %Z\n"` is not `@safe`
fail_compilation/safeprintf.d(21):        `safeprintf.printf` is declared here
fail_compilation/safeprintf.d(31): Deprecation: format specifier `"%Z"` is invalid
fail_compilation/safeprintf.d(32): Error: calling `pragma(printf)` function `safeprintf.printf` with non-literal format string is not `@safe`
fail_compilation/safeprintf.d(21):        `safeprintf.printf` is declared here
fail_compilation/safeprintf.d(33): Error: calling `pragma(printf)` function `safeprintf.bar` with format string `"%s"` is not `@safe`
fail_compilation/safeprintf.d(22):        `safeprintf.bar` is declared here
fail_compilation/safeprintf.d(34): Error: `@safe` function `safeprintf.func` cannot call `@system` function `safeprintf.sys_printf`
fail_compilation/safeprintf.d(23):        `safeprintf.sys_printf` is declared here
---
*/

extern (C) @trusted pragma(printf) int printf(const(char)* format, ...);
extern(C) pragma(printf) @trusted void bar(int, const char*, ...);
extern (C) @system pragma(printf) int sys_printf(const(char)* format, ...);

@safe void func(int i, char* s, dchar* d)
{
    printf("no specs"); // OK
    printf("i: %d\n", i); // OK
    printf("s: %s\n", s);
    printf("s: %S\n", d);
    printf("s: %Z\n", s);
    printf(s, i); // non-literal
    bar(1, "%s", s); // preceding args
    sys_printf("d", i);
}
