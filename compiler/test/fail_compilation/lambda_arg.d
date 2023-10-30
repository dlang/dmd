/*
TEST_OUTPUT:
---
fail_compilation/lambda_arg.d(16): Error: function `lambda_arg.foo(int function(int) f)` is not callable using argument types `(void)`
fail_compilation/lambda_arg.d(16):        cannot implicitly convert expression `__lambda2` of type `double function(int x) pure nothrow @nogc @safe` to `int function(int)`
fail_compilation/lambda_arg.d(17): Error: function `lambda_arg.foo(int function(int) f)` is not callable using argument types `(void)`
fail_compilation/lambda_arg.d(17):        cannot infer parameter types for `__lambda3` from `int function(int)`
fail_compilation/lambda_arg.d(18): Error: function `lambda_arg.foo(int function(int) f)` is not callable using argument types `(void)`
fail_compilation/lambda_arg.d(18):        cannot match delegate literal to function pointer type `int function(int)`
---
*/
void foo(int function(int) f) {}

void main() {
    foo(x => 0);      // OK
    foo(x => 0.0);
    foo((x, y) => 0);
    foo(delegate(x) => 0);
}
