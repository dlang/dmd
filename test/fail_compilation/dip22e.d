/*
TEST_OUTPUT:
---
fail_compilation/dip22e.d(13): Error: undefined identifier `foo`, did you mean struct `Foo`?
---
*/

import imports.dip22d;
import imports.dip22e;

void test()
{
    foo();
    bar(12);
}
