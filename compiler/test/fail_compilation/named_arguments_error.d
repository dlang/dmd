/*
TEST_OUTPUT:
---
fail_compilation/named_arguments_error.d(67): Error: function `f` is not callable using argument types `(int, int, int)`
	f(x: 3, x: 3, 5);
  ^
fail_compilation/named_arguments_error.d(67):        parameter `x` assigned twice
fail_compilation/named_arguments_error.d(61):        `named_arguments_error.f(int x, int y, int z)` declared here
void f(int x, int y, int z);
     ^
fail_compilation/named_arguments_error.d(68): Error: function `f` is not callable using argument types `(int, int, int)`
	f(z: 3,    4, 5);
  ^
fail_compilation/named_arguments_error.d(68):        argument `4` goes past end of parameter list
fail_compilation/named_arguments_error.d(61):        `named_arguments_error.f(int x, int y, int z)` declared here
void f(int x, int y, int z);
     ^
fail_compilation/named_arguments_error.d(69): Error: function `f` is not callable using argument types `(int, int, int)`
	f(y: 3, x: 4, 5);
  ^
fail_compilation/named_arguments_error.d(69):        parameter `y` assigned twice
fail_compilation/named_arguments_error.d(61):        `named_arguments_error.f(int x, int y, int z)` declared here
void f(int x, int y, int z);
     ^
fail_compilation/named_arguments_error.d(70): Error: function `f` is not callable using argument types `(int, int, int)`
	f(a: 3, b: 4, 5);
  ^
fail_compilation/named_arguments_error.d(70):        no parameter named `a`
fail_compilation/named_arguments_error.d(61):        `named_arguments_error.f(int x, int y, int z)` declared here
void f(int x, int y, int z);
     ^
fail_compilation/named_arguments_error.d(71): Error: function `g` is not callable using argument types `(int, int)`
	g(y: 4, z: 3);
  ^
fail_compilation/named_arguments_error.d(71):        missing argument for parameter #1: `int x`
fail_compilation/named_arguments_error.d(63):        `named_arguments_error.g(int x, int y, int z = 3)` declared here
int g(int x, int y, int z = 3);
    ^
fail_compilation/named_arguments_error.d(73): Error: no named argument `element` allowed for array dimension
	auto g0 = new int[](element: 3);
           ^
fail_compilation/named_arguments_error.d(74): Error: no named argument `number` allowed for scalar
	auto g1 = new int(number: 3);
           ^
fail_compilation/named_arguments_error.d(75): Error: cannot implicitly convert expression `g(x: 3, y: 4, z: 5)` of type `int` to `string`
	string s = g(x: 3, y: 4, z: 5);
             ^
fail_compilation/named_arguments_error.d(76): Error: template `tempfun` is not callable using argument types `!()(int, int)`
	enum x = tempfun(u: 0, 1);
                 ^
fail_compilation/named_arguments_error.d(79):        Candidate is: `tempfun(T, U)(T t, U u)`
int tempfun(T, U)(T t, U u)
    ^
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
