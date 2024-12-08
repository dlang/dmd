/*
EXTRA_FILES: imports/a11850.d
TEST_OUTPUT:
---
fail_compilation/ice11850.d(21): Error: incompatible types for `(a) < ([0])`: `uint[]` and `int[]`
    filter!(a => a < [0])([[0u]]);
                 ^
fail_compilation/imports/a11850.d(9):        instantiated from here: `FilterResult!(__lambda_L21_C13, uint[][])`
        return FilterResult!(pred, Range)(rs);
               ^
fail_compilation/ice11850.d(21):        instantiated from here: `filter!(uint[][])`
    filter!(a => a < [0])([[0u]]);
                         ^
---
*/

import imports.a11850 : filter;

void main()
{
    filter!(a => a < [0])([[0u]]);
}
