/*
TEST_OUTPUT:
---
fail_compilation/ice13259.d(8): Error: non-constant nested delegate literal expression `__dgliteral3`
---
*/

auto dg = delegate {};
