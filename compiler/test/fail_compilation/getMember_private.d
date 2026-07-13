/*
EXTRA_FILES: imports/fail5385.d
TEST_OUTPUT:
---
fail_compilation/getMember_private.d(17): Error: accessing member `x` is not allowed in a `@safe` function
fail_compilation/getMember_private.d(19): Error: accessing member `privX` is not allowed in a `@safe` function
---
*/

import imports.a10169, imports.fail5385;

B b;

void f() @safe
{
    // instance field
    __traits(getMember, b, "x")++;
    // static field
    __traits(getMember, C, "privX")++;
}

void g() @system // OK
{
    __traits(getMember, b, "x")++;
    __traits(getMember, C, "privX")++;
}
