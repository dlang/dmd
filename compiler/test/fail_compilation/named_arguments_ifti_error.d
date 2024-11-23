/*
TEST_OUTPUT:
---
fail_compilation/named_arguments_ifti_error.d(29): Error: template `f` is not callable using argument types `!()(int, int)`
	f(x: 3, x: 3); // double assignment of x
  ^
fail_compilation/named_arguments_ifti_error.d(25):        Candidate is: `f(T, U)(T x, U y)`
void f(T, U)(T x, U y) {}
     ^
fail_compilation/named_arguments_ifti_error.d(30): Error: template `f` is not callable using argument types `!()(int, int)`
	f(y: 3,    3); // overflow past last parameter
  ^
fail_compilation/named_arguments_ifti_error.d(25):        Candidate is: `f(T, U)(T x, U y)`
void f(T, U)(T x, U y) {}
     ^
fail_compilation/named_arguments_ifti_error.d(31): Error: template `f` is not callable using argument types `!()(int)`
	f(y: 3);       // skipping parameter x
  ^
fail_compilation/named_arguments_ifti_error.d(25):        Candidate is: `f(T, U)(T x, U y)`
void f(T, U)(T x, U y) {}
     ^
---
*/

void f(T, U)(T x, U y) {}

void main()
{
	f(x: 3, x: 3); // double assignment of x
	f(y: 3,    3); // overflow past last parameter
	f(y: 3);       // skipping parameter x
}
