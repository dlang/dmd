/*
TEST_OUTPUT:
---
fail_compilation/staticassertargsfail.d(9): Error: incompatible types for `(['x', 'e']) ~ (new Object)`: `char[]` and `object.Object`
fail_compilation/staticassertargsfail.d(9):        while evaluating `static assert(['x', 'e'] ~ new Object)`
---
*/

static assert(0, "abc", ['x', 'e'] ~ new Object);
