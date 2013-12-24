/*
TEST_OUTPUT:
---
fail_compilation/fail356b.d(13): Error: no property 'max' for type 'string'
---
*/

import imports.fail356 : bar;
string bar; // doesn't collide with selective import

void main()
{
    auto x = bar.max;
    // string 'bar' hides imported int 'bar'
}
