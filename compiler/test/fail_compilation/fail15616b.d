/*
REQUIRED_ARGS: -v
TRANSFORM_OUTPUT: remove_lines("^(predefs|binary|version|config|DFLAG|parse|import|\(imported|semantic|entry|\s*$)")
TEST_OUTPUT:
---
fail_compilation/fail15616b.d(44): Error: none of the overloads of `foo` are callable using argument types `(double)`
fail_compilation/fail15616b.d(17):        Candidate 1 is: `fail15616b.foo(int a)`
fail_compilation/fail15616b.d(20):        Candidate 2 is: `fail15616b.foo(int a, int b)`
fail_compilation/fail15616b.d(29):        Candidate 3 is: `fail15616b.foo(int a, int b, int c)`
fail_compilation/fail15616b.d(32):        Candidate 4 is: `fail15616b.foo(string a)`
fail_compilation/fail15616b.d(35):        Candidate 5 is: `fail15616b.foo(string a, string b)`
fail_compilation/fail15616b.d(38):        Candidate 6 is: `fail15616b.foo(string a, string b, string c)`
fail_compilation/fail15616b.d(44):        ... (2 more, -v to show) ...
  with `T = double`
  whose parameters have the following constraints:
  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
`  > is(T == float)
`  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
fail_compilation/fail15616b.d(26):                        `foo(T)(T a)`
  with `T = double`
  whose parameters have the following constraints:
  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
`  > is(T == char)
`  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`
  Tip: not satisfied constraints are marked with `>`
---
*/

#line 17
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
