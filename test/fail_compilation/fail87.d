/*
TEST_OUTPUT:
---
fail_compilation/fail87.d(8): Error: circular reference to 'a'
---
*/

auto a = .a;
