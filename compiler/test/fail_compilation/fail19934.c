// https://issues.dlang.org/show_bug.cgi?id=21964
/* TEST_OUTPUT:
REQUIRED_ARGS: -verrors=context
---
fail_compilation/fail19934.c(14): Error: static array parameters are not supported
void f(int a[static 10])
            ^
fail_compilation/fail19934.c(18): Error: variable length arrays are not supported
void g(int n, int a[*])
                   ^
---
*/

void f(int a[static 10])
{
}

void g(int n, int a[*])
{
}
