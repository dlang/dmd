// https://issues.dlang.org/show_bug.cgi?id=21964
/* TEST_OUTPUT:
REQUIRED_ARGS: -verrors=context
---
fail_compilation/fail19934.c(15): Error: variable length arrays are not supported
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
