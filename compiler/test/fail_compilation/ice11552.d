/*
REQUIRED_ARGS: -o-
TEST_OUTPUT:
---
fail_compilation/ice11552.d(19): Error: function `ice11552.test11552` label `label` is undefined
    goto label;
    ^
fail_compilation/ice11552.d(22):        called from here: `test11552()`
static assert(test11552());
                       ^
fail_compilation/ice11552.d(22):        while evaluating: `static assert(test11552())`
static assert(test11552());
^
---
*/

int test11552()
{
    goto label;
    return 1;
}
static assert(test11552());
