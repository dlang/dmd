/*
TEST_OUTPUT:
---
fail_compilation/enum9921.d(1): Error: enum enum9921.X base type must not be void
fail_compilation/enum9921.d(3): Error: enum enum9921.Z base type must not be void
---
*/

#line 1
enum X : void;

enum Z : void { Y };
