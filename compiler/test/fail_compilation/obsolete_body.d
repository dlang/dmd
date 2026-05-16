/*
TEST_OUTPUT:
---
fail_compilation/obsolete_body.d(11): Error: usage of identifer `body` as a keyword is obsolete. Use `do` instead.
fail_compilation/obsolete_body.d(13): Error: use `alias i32 = ...;` syntax instead of `alias ... i32;`
---
*/
module m 2024;

void test()
in { } body { }

alias int i32;
