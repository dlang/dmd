/*
REQUIRED_ARGS: -verror-supplements=0
TEST_OUTPUT:
---
fail_compilation/fail15616c.d(69): Error: none of the overloads of `foo` are callable using argument types `(double)`
    foo(3.14);
       ^
fail_compilation/fail15616c.d(42):        Candidates are: `fail15616c.foo(int a)`
void foo(int a)
     ^
fail_compilation/fail15616c.d(45):                        `fail15616c.foo(int a, int b)`
void foo(int a, int b)
     ^
fail_compilation/fail15616c.d(54):                        `fail15616c.foo(int a, int b, int c)`
void foo(int a, int b, int c)
     ^
fail_compilation/fail15616c.d(57):                        `fail15616c.foo(string a)`
void foo(string a)
     ^
fail_compilation/fail15616c.d(60):                        `fail15616c.foo(string a, string b)`
void foo(string a, string b)
     ^
fail_compilation/fail15616c.d(63):                        `fail15616c.foo(string a, string b, string c)`
void foo(string a, string b, string c)
     ^
fail_compilation/fail15616c.d(48):                        `foo(T)(T a)`
  with `T = double`
  must satisfy the following constraint:
`       is(T == float)`
void foo(T)(T a) if (is(T == float))
     ^
fail_compilation/fail15616c.d(51):                        `foo(T)(T a)`
  with `T = double`
  must satisfy the following constraint:
`       is(T == char)`
void foo(T)(T a) if (is(T == char))
     ^
---
*/

// Line 17 starts here
void foo(int a)
{}

void foo(int a, int b)
{}

void foo(T)(T a) if (is(T == float))
{}

void foo(T)(T a) if (is(T == char))
{}

void foo(int a, int b, int c)
{}

void foo(string a)
{}

void foo(string a, string b)
{}

void foo(string a, string b, string c)
{}


void main()
{
    foo(3.14);
}
