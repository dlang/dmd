/*
TEST_OUTPUT:
---
fail_compilation/fail15616a.d(58): Error: none of the overloads of `foo` are callable using argument types `(double)`
    foo(3.14);
       ^
fail_compilation/fail15616a.d(31):        Candidates are: `fail15616a.foo(int a)`
void foo(int a)
     ^
fail_compilation/fail15616a.d(34):                        `fail15616a.foo(int a, int b)`
void foo(int a, int b)
     ^
fail_compilation/fail15616a.d(43):                        `fail15616a.foo(int a, int b, int c)`
void foo(int a, int b, int c)
     ^
fail_compilation/fail15616a.d(46):                        `fail15616a.foo(string a)`
void foo(string a)
     ^
fail_compilation/fail15616a.d(49):                        `fail15616a.foo(string a, string b)`
void foo(string a, string b)
     ^
fail_compilation/fail15616a.d(52):                        `fail15616a.foo(string a, string b, string c)`
void foo(string a, string b, string c)
     ^
fail_compilation/fail15616a.d(58):        ... (2 more, -v to show) ...
    foo(3.14);
       ^
---
*/
// Line 14 starts here
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
