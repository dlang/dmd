/*
TEST_OUTPUT:
---
fail_compilation/ice9865.d(9): Error: struct ice9865.Foo no size yet for forward reference
fail_compilation/ice9865.d(8): Error: alias ice9865.Baz recursive alias declaration
---
*/
import imports.ice9865b : Baz;
struct Foo { Baz f; }
