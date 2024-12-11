/*
REQUIRED_ARGS: -v
TRANSFORM_OUTPUT: remove_lines("^(predefs|binary|version|config|DFLAG|parse|import|semantic|entry|\s*$)")
TEST_OUTPUT:
---
fail_compilation/fail15616b.d(75): Error: none of the overloads of `foo` are callable using argument types `(double)`
    foo(3.14);
       ^
fail_compilation/fail15616b.d(48):        Candidates are: `fail15616b.foo(int a)`
void foo(int a)
     ^
fail_compilation/fail15616b.d(51):                        `fail15616b.foo(int a, int b)`
void foo(int a, int b)
     ^
fail_compilation/fail15616b.d(60):                        `fail15616b.foo(int a, int b, int c)`
void foo(int a, int b, int c)
     ^
fail_compilation/fail15616b.d(63):                        `fail15616b.foo(string a)`
void foo(string a)
     ^
fail_compilation/fail15616b.d(66):                        `fail15616b.foo(string a, string b)`
void foo(string a, string b)
     ^
fail_compilation/fail15616b.d(69):                        `fail15616b.foo(string a, string b, string c)`
void foo(string a, string b, string c)
     ^
fail_compilation/fail15616b.d(54):                        `foo(T)(T a)`
  with `T = double`
  whose parameters have the following constraints:
  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
`  > is(T == float)
`  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
void foo(T)(T a) if (is(T == float))
     ^
fail_compilation/fail15616b.d(57):                        `foo(T)(T a)`
  with `T = double`
  whose parameters have the following constraints:
  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
`  > is(T == char)
`  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
void foo(T)(T a) if (is(T == char))
     ^
  Tip: not satisfied constraints are marked with `>`
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
