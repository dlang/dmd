/* TEST_OUTPUT:
---
fail_compilation/fail17421.d(22): Error: argument to `__traits(getFunctionVariadicStyle, 1)` is not a function
static assert(__traits(getFunctionVariadicStyle, 1) == "none");
              ^
fail_compilation/fail17421.d(22):        while evaluating: `static assert(__traits(getFunctionVariadicStyle, 1) == "none")`
static assert(__traits(getFunctionVariadicStyle, 1) == "none");
^
fail_compilation/fail17421.d(23): Error: argument to `__traits(getFunctionVariadicStyle, int*)` is not a function
static assert(__traits(getFunctionVariadicStyle, x) == "none");
              ^
fail_compilation/fail17421.d(23):        while evaluating: `static assert(__traits(getFunctionVariadicStyle, int*) == "none")`
static assert(__traits(getFunctionVariadicStyle, x) == "none");
^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17421

alias int* x;

static assert(__traits(getFunctionVariadicStyle, 1) == "none");
static assert(__traits(getFunctionVariadicStyle, x) == "none");
