/*
TEST_OUTPUT:
---
fail_compilation/ice22377.d(8): Error: internal compiler error: type `string` cannot be mapped to C++
---
*/

extern(C++) void foo(string a) {}
