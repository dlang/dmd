/*
TEST_OUTPUT:
---
fail_compilation/ice11850.d(16): Error: incompatible types for ((a) < ([0])): 'uint[]' and 'int[]'
fail_compilation/imports/a11850.d(9):        instantiated from here: FilterResult!(__lambda1, uint[][])
fail_compilation/ice11850.d(16):        instantiated from here: filter!(uint[][])
fail_compilation/ice11850.d(16): Error: template imports.a11850.filter cannot deduce function from argument types !((a) => a < [0])(uint[][]), candidates are:
fail_compilation/imports/a11850.d(5):        imports.a11850.filter(alias pred)
---
*/

import imports.a11850 : filter;

void main()
{
    filter!(a => a < [0])([[0u]]);
}
