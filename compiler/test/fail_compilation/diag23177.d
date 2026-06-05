// EXTRA_FILES: imports/imp23177.c
// https://github.com/dlang/dmd/issues/23177

/*
TEST_OUTPUT:
---
fail_compilation/diag23177.d(22): Error: function `run` is not callable using argument types `(extern (C) int function())`
fail_compilation/diag23177.d(22):        cannot pass argument `& callback` of type `extern (C) int function()` to parameter `extern (C) int function(<K&R variadics>) fn`
fail_compilation/imports/imp23177.c(5):        `imp23177.run(extern (C) int function(<K&R variadics>) fn)` declared here
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
