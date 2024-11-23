/*
TEST_OUTPUT:
----
fail_compilation/b19523.d(19): Error: undefined identifier `SomeStruct`
	SomeStruct s;
            ^
fail_compilation/b19523.d(20): Error: function `foo` is not callable using argument types `(_error_)`
	foo({
    ^
fail_compilation/b19523.d(20):        cannot pass argument `__lambda_L20_C6` of type `_error_` to parameter `int delegate() arg`
fail_compilation/b19523.d(25):        `b19523.foo(int delegate() arg)` declared here
void foo (int delegate() arg) {}
     ^
----
*/
module b19523;

void bar () {
	SomeStruct s;
	foo({
		return s;
	});
}

void foo (int delegate() arg) {}
