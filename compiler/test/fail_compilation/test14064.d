/*
TEST_OUTPUT:
---
fail_compilation/test14064.d(21): Error: `private` is a keyword, not an `@` attribute
@private int v;
 ^
fail_compilation/test14064.d(22): Error: `deprecated` is a keyword, not an `@` attribute
@deprecated void foo();
 ^
fail_compilation/test14064.d(23): Error: `pure` is a keyword, not an `@` attribute
int goo() @pure;
           ^
fail_compilation/test14064.d(24): Error: `nothrow` is a keyword, not an `@` attribute
@nothrow unittest {};
 ^
fail_compilation/test14064.d(25): Error: `in` is a keyword, not an `@` attribute
void zoom(@in int x);
           ^
---
*/
@private int v;
@deprecated void foo();
int goo() @pure;
@nothrow unittest {};
void zoom(@in int x);
