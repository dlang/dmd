// https://github.com/dlang/dmd/issues/21265

// Test #pragma comment(lib, "name")

#pragma comment(lib, "test21265.lib")

// other comment-types are silently skipped
#pragma comment(compiler)
#pragma comment(exestr, "built with dmd")
#pragma comment(linker, "/include:_x")
#pragma comment(user, "test21265")

int x;

// honored even outside file scope, e.g. inside a function body
int f(void)
{
#pragma comment(lib, "test21265b.lib")
    return 1;
}
