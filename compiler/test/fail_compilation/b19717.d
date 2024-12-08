/*
TEST_OUTPUT:
---
fail_compilation/b19717.d(22): Error: undefined identifier `Foo`, did you mean function `foo`?
void foo(Foo) {}
     ^
fail_compilation/b19717.d(19): Error: forward reference to template `foo`
	return foo();
           ^
fail_compilation/b19717.d(19): Error: forward reference to inferred return type of function call `foo()`
	return foo();
           ^
---
*/

enum bar = __traits(getMember, mixin(__MODULE__), "foo");

auto foo() {
	return foo();
}

void foo(Foo) {}
