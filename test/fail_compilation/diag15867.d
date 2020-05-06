/*
TEST_OUTPUT:
---
fail_compilation/diag15867.d(9): Error: cannot implicitly convert expression `Foo()` of type `immutable(Foo)` to `diag15867.Foo`
---
*/

class ThisIsWhereTheErrorIs {
		Foo foo = Foo.instance;  // error location
}

immutable class Foo {
	private this() {}
	static immutable Foo instance = new immutable Foo();
}
