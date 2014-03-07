/*
TEST_OUTPUT:
---
fail_compilation/ice11850.d(15): Error: incompatible types for ((a) < ([0])): 'uint[]' and 'int[]'
fail_compilation/imports/a11850.d(9):        instantiated from here: FilterResult!(__lambda1, uint[][])
fail_compilation/ice11850.d(15):        instantiated from here: filter!(uint[][])
fail_compilation/ice11850.d(15): Error: template instance ice11850.main.filter!((a) => a < [0]).filter!(uint[][]) error instantiating
---
*/

import imports.a11850 : filter;

void main()
{
    filter!(a => a < [0])([[0u]]);
}



