/*
REQUIRED_ARGS: -edition=2024
TEST_OUTPUT:
---
fail_compilation/edition_switch.d(13): Error: usage of identifer `body` as a keyword is obsolete. Use `do` instead.
---
*/

// test -edition can override a lower module declaration
module m 2023;

void test()
in { } body { }
