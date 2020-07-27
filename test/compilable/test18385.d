/*
Reduced from the assertion failure in the glue layer when compiling DWT.
A `compilable` test because it needs codegen.

Remove this test once the deprecation for conflicting deprecations ends,
see visit(FuncDeclaration) in semantic2.d for details.

TEST_OUTPUT:
---
compilable/test18385.d(17): Deprecation: function `test18385.is_paragraph_start()` cannot be overloaded with another `extern(C)` function at compilable/test18385.d(16)
---
*/

extern(C)
{
	uint is_paragraph_start(){ return 0; }
	uint is_paragraph_start(){ return 0; }
}
