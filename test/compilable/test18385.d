/*
Reduced from the assertion failure in the glue layer when compiling DWT.
A `compilable` test because it needs codegen.

Remove this test once the deprecation for conflicting deprecations ends,
see visit(FuncDeclaration) in semantic2.d for details.

TEST_OUTPUT:
---
compilable/test18385.d(23): Deprecation: function `test18385.is_paragraph_start` cannot overload `extern(C)` function at compilable/test18385.d(22)
compilable/test18385.d(26): Deprecation: function `test18385.foo` cannot overload `extern(C)` function at compilable/test18385.d(25)
compilable/test18385.d(29): Deprecation: function `test18385.trust` cannot overload `extern(C)` function at compilable/test18385.d(28)
compilable/test18385.d(32): Deprecation: function `test18385.purity` cannot overload `extern(C)` function at compilable/test18385.d(31)
compilable/test18385.d(35): Deprecation: function `test18385.nogc` cannot overload `extern(C)` function at compilable/test18385.d(34)
compilable/test18385.d(38): Deprecation: function `test18385.nothrow_` cannot overload `extern(C)` function at compilable/test18385.d(37)
compilable/test18385.d(41): Deprecation: function `test18385.live` cannot overload `extern(C)` function at compilable/test18385.d(40)
---
*/

extern(C)
{
	uint is_paragraph_start(){ return 0; }
	uint is_paragraph_start(int){ return 0; }

	void foo(char, bool) {}
	void foo(byte, char) {}

	void trust() {}
	void trust() @safe {}

	void purity() {}
	void purity() pure {}

	void nogc() {}
	void nogc() @safe {}

	void nothrow_() {}
	void nothrow_() nothrow {}

	void live() {}
	void live() @live {}
}
