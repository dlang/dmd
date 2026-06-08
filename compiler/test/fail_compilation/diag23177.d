// EXTRA_FILES: imports/imp23177.c
// https://github.com/dlang/dmd/issues/23177

/*
TEST_OUTPUT:
---
fail_compilation/diag23177.d(25): Error: function `run1` is not callable using argument types `(extern (C) int function())`
fail_compilation/diag23177.d(25):        cannot pass argument `& callback` of type `extern (C) int function()` to parameter `extern (C) int function(<K&R variadic>) fn`
fail_compilation/imports/imp23177.c(4):        `imp23177.run1(extern (C) int function(<K&R variadic>) fn)` declared here
fail_compilation/diag23177.d(26): Error: function `run2` is not callable using argument types `(extern (C) int function(<K&R variadic>))`
fail_compilation/diag23177.d(26):        cannot pass argument `& f` of type `extern (C) int function(<K&R variadic>)` to parameter `extern (C) int function(int a) fn`
fail_compilation/imports/imp23177.c(14):        `imp23177.run2(extern (C) int function(int a) fn)` declared here
---
*/

import imports.imp23177;

extern (C) int callback()
{
    return 42;
}

void main()
{
    run1(&callback);
    run2(&f);
}
