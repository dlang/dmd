// https://issues.dlang.org/show_bug.cgi?id=10273
// ICE in CTFE
/*
TEST_OUTPUT:
---
fail_compilation/ice10273.d(22): Error: cannot implicitly convert expression `3.45` of type `double` to `int`
    int val = 3.45;
              ^
fail_compilation/ice10273.d(21): Error: CTFE failed because of previous errors in `Bug10273.init`
struct Bug10273 {
^
fail_compilation/ice10273.d(30):        called from here: `bug10273()`
static assert(bug10273());
                      ^
fail_compilation/ice10273.d(30):        while evaluating: `static assert(bug10273())`
static assert(bug10273());
^
---
*/

struct Bug10273 {
    int val = 3.45;
}
int bug10273()
{
    Bug10273 p;
    return 1;
}

static assert(bug10273());
