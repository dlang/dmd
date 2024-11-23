/*
TEST_OUTPUT:
---
fail_compilation/fail8313.d(17): Error: `fail8313.bar` called with argument types `(int)` matches both:
fail_compilation/fail8313.d(15):     `fail8313.bar!().bar(int x)`
and:
fail_compilation/fail8313.d(16):     `fail8313.bar!().bar(int x)`
static assert(bar(1));
                 ^
fail_compilation/fail8313.d(17):        while evaluating: `static assert(bar()(int x)(1))`
static assert(bar(1));
^
---
*/
auto bar()(int x){return x;}
auto bar()(int x = bar()){return x;}
static assert(bar(1));
