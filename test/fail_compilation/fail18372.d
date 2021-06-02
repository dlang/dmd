/*
DISABLED: win32 win64 linux32 osx32 freebsd32
TEST_OUTPUT:
---
fail_compilation/fail18372.d(103): Error: `__va_list_tag` is not defined, perhaps `import core.stdc.stdarg;` ?
---
*/

#line 100

// https://issues.dlang.org/show_bug.cgi?id=18372

void fun(const(char)* a, ...) { }

void test()
{
    fun("abc");
}

