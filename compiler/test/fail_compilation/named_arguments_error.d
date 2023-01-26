/*
TEST_OUTPUT:
---
fail_compilation/named_arguments_error.d(26): Error: function `named_arguments_error.f(int x, int y, int z)` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(26):        parameter `x` assigned twice
fail_compilation/named_arguments_error.d(27): Error: function `named_arguments_error.f(int x, int y, int z)` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(27):        argument `4` goes past end of parameter list
fail_compilation/named_arguments_error.d(28): Error: function `named_arguments_error.f(int x, int y, int z)` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(28):        parameter `y` assigned twice
fail_compilation/named_arguments_error.d(29): Error: function `named_arguments_error.g(int x, int y, int z = 3)` is not callable using argument types `(int, int)`
fail_compilation/named_arguments_error.d(29):        missing argument for parameter #1: `int x`
fail_compilation/named_arguments_error.d(31): Error: no named argument `element` allowed for array dimension
fail_compilation/named_arguments_error.d(32): Error: no named argument `number` allowed for scalar
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

	auto g0 = new int[](element: 3);
	auto g1 = new int(number: 3);
}
