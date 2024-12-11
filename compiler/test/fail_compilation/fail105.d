/*
TEST_OUTPUT:
---
fail_compilation/fail105.d(13): Error: cannot cast `"bar"` to `int` at compile time
int bar = cast(int)cast(char*)"bar";
                              ^
---
*/

//int foo = "foo";

// just Access Violation happens.
int bar = cast(int)cast(char*)"bar";
