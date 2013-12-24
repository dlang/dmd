/*
TEST_OUTPUT:
---
fail_compilation/fail356c.d(13): Error: function expected before (), not bar of type int
---
*/

import foo = imports.fail356;
int foo; // doesn't collide with renamed import

void main()
{
    auto x = foo.bar;   // --> rewritten to bar(foo) by UFCS
    // declared 'foo' hides renamed module name 'foo'
}
