/*
TEST_OUTPUT:
---
fail_compilation/ice9865.d(9): Deprecation: module `ice9865b` from file fail_compilation/imports/ice9865b.d should be imported with 'import ice9865b;'
fail_compilation/ice9865.d(9): Error: alias `ice9865.Baz` recursive alias declaration
---
*/

public import imports.ice9865b : Baz;
struct Foo { Baz f; }
