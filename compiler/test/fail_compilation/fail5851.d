/*
TEST_OUTPUT:
---
fail_compilation/fail5851.d(13): Error: alias this is not reachable as `Foo` already converts to `object.Object`
    alias o this;
    ^
---
*/

class Foo
{
    Object o;
    alias o this;
}

void main()
{
}
