/*
TEST_OUTPUT:
---
fail_compilation/fail63.d(13): Error: debug `Foo` defined after use
debug = Foo;
        ^
---
*/

debug (Foo)
    int x;

debug = Foo;
