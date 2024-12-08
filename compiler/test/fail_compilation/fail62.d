/*
TEST_OUTPUT:
---
fail_compilation/fail62.d(13): Error: version `Foo` defined after use
version = Foo;
          ^
---
*/

version (Foo)
    int x;

version = Foo;
