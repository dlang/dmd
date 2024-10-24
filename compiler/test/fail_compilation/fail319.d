/*
TEST_OUTPUT:
---
fail_compilation/fail319.d(106): Error: template instance `fail319.f!(int, int)` does not match template declaration `f(T...)()`
  with `T = (int, int)`
  must satisfy the following constraint:
`       T.length > 20`
fail_compilation/fail319.d(106):        instantiated from here: `f!(int, int)`
fail_compilation/fail319.d(101):        Candidate match: f(T...)() if (T.length > 20)
---
*/

#line 100

void f(T...)() if (T.length > 20)
{}

void main()
{
    f!(int, int)();
}
