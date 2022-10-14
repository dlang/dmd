/*
TEST_OUTPUT:
---
fail_compilation/named_arguments_error.d(21): Error: function `named_arguments_error.f(int x, int y, int z)` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(21):        parameter `x` assigned twice
fail_compilation/named_arguments_error.d(22): Error: function `named_arguments_error.f(int x, int y, int z)` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(22):        argument `4` goes past end of parameter list
fail_compilation/named_arguments_error.d(23): Error: function `named_arguments_error.f(int x, int y, int z)` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(23):        parameter `y` assigned twice
fail_compilation/named_arguments_error.d(24): Error: function `named_arguments_error.g(int x, int y, int z = 3)` is not callable using argument types `(int, int)`
fail_compilation/named_arguments_error.d(24):        missing argument for parameter #1: `int x`
---
*/

void f(int x, int y, int z);

void g(int x, int y, int z = 3);

void main()
{
	f(x: 3, x: 3, 5);
	f(z: 3,    4, 5);
	f(y: 3, x: 4, 5);
	g(y: 4, z: 3);
}
