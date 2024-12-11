/*
TEST_OUTPUT:
---
fail_compilation/staticassertargsfail.d(14): Error: incompatible types for `('x') : (new Object)`: `char` and `object.Object`
static assert(0, "abc", ['x', new Object] ~ "");
                              ^
fail_compilation/staticassertargsfail.d(14):        while evaluating `static assert` argument `['x', new Object] ~ ""`
static assert(0, "abc", ['x', new Object] ~ "");
^
---
*/


static assert(0, "abc", ['x', new Object] ~ "");
