/*
TEST_OUTPUT:
---
fail_compilation/named_arguments_error.d(38): Error: function `f` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(38):        parameter `x` assigned twice
fail_compilation/named_arguments_error.d(32):        `named_arguments_error.f(int x, int y, int z)` declared here
fail_compilation/named_arguments_error.d(39): Error: function `f` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(39):        argument `4` goes past end of parameter list
fail_compilation/named_arguments_error.d(32):        `named_arguments_error.f(int x, int y, int z)` declared here
fail_compilation/named_arguments_error.d(40): Error: function `f` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(40):        parameter `y` assigned twice
fail_compilation/named_arguments_error.d(32):        `named_arguments_error.f(int x, int y, int z)` declared here
fail_compilation/named_arguments_error.d(41): Error: function `f` is not callable using argument types `(int, int, int)`
fail_compilation/named_arguments_error.d(41):        no parameter named `a`
fail_compilation/named_arguments_error.d(32):        `named_arguments_error.f(int x, int y, int z)` declared here
fail_compilation/named_arguments_error.d(42): Error: function `g` is not callable using argument types `(int, int)`
fail_compilation/named_arguments_error.d(42):        missing argument for parameter #1: `int x`
fail_compilation/named_arguments_error.d(34):        `named_arguments_error.g(int x, int y, int z = 3)` declared here
fail_compilation/named_arguments_error.d(44): Error: no named argument `element` allowed for array dimension
fail_compilation/named_arguments_error.d(45): Error: no named argument `number` allowed for scalar
fail_compilation/named_arguments_error.d(46): Error: cannot implicitly convert expression `g(x: 3, y: 4, z: 5)` of type `int` to `string`
fail_compilation/named_arguments_error.d(47): Error: template `tempfun` is not callable using argument types `!()(int, int)`
fail_compilation/named_arguments_error.d(47):        argument `1` goes past end of parameter list
fail_compilation/named_arguments_error.d(50):        Candidate is: `tempfun(T, U)(T t, U u)`
---
*/





void f(int x, int y, int z);

int g(int x, int y, int z = 3);

void main()
{
	f(x: 3, x: 3, 5);
	f(z: 3,    4, 5);
	f(y: 3, x: 4, 5);
	f(a: 3, b: 4, 5);
	g(y: 4, z: 3);

	auto g0 = new int[](element: 3);
	auto g1 = new int(number: 3);
	string s = g(x: 3, y: 4, z: 5);
	enum x = tempfun(u: 0, 1);
}

int tempfun(T, U)(T t, U u)
{
    return 3;
}
