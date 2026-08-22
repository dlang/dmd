/*
TEST_OUTPUT:
---
fail_compilation/fail20739.d(20): Error: template `f` is not callable using argument types `!()(A!(1, 2))`
    f(a);
     ^
fail_compilation/fail20739.d(15):        Candidate is: `f(int M)(A!(M - 1, M) a)`
void f(int M)(A!(M - 1, M) a) {}
     ^
---
*/

struct A(int M, int N) {}

void f(int M)(A!(M - 1, M) a) {}

void test20739()
{
    A!(1, 2) a;
    f(a);
}
