// EXTRA_SOURCES: imports/imp23177.c
// EXTRA_FILES: imports/imp23177.c
// https://github.com/dlang/dmd/issues/23177

/*
TEST_OUTPUT:
---
fail_compilation/diag23177.d(24): Error: function `run` is not callable using argument types `(extern (C) int function())`
fail_compilation/diag23177.d(24):        cannot pass argument `& callback` of type `extern (C) int function()` to parameter `extern (C) int function() fn`
ImportC: C `f()` means parameters are unspecified, not none; use `f(void)` for no parameters
fail_compilation/imports/imp23177.c(5):        `imp23177.run(extern (C) int function() fn)` declared here
---
*/

import imports.imp23177;

extern (C) int callback()
{
    return 42;
}

void main()
{
    run(&callback);
}
