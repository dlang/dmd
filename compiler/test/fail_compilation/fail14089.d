/*
TEST_OUTPUT:
---
fail_compilation/fail14089.d(61): Error: `1` has no effect
    cond ? 1     : 1;
           ^
fail_compilation/fail14089.d(61): Error: `1` has no effect
    cond ? 1     : 1;
                   ^
fail_compilation/fail14089.d(62): Error: `1` has no effect
    cond ? 1     : n;
           ^
fail_compilation/fail14089.d(62): Error: `n` has no effect
    cond ? 1     : n;
                   ^
fail_compilation/fail14089.d(63): Error: `1` has no effect
    cond ? 1     : s.val;
           ^
fail_compilation/fail14089.d(63): Error: `s.val` has no effect
    cond ? 1     : s.val;
                   ^
fail_compilation/fail14089.d(64): Error: `n` has no effect
    cond ? n     : 1;
           ^
fail_compilation/fail14089.d(64): Error: `1` has no effect
    cond ? n     : 1;
                   ^
fail_compilation/fail14089.d(65): Error: `s.val` has no effect
    cond ? s.val : 1;
           ^
fail_compilation/fail14089.d(65): Error: `1` has no effect
    cond ? s.val : 1;
                   ^
---
*/

bool cond;

void main()
{
    int foo() { return 0; }
    int n;
    struct S { int val; }
    S s;

    // The whole of each CondExps has side effects, So no error.
    cond ? foo() : n;
    cond ? foo() : s.val;
    cond ? 1     : foo();
    cond ? n     : foo();
    cond ? s.val : foo();

    cond ? (n = 1) : 1;
    cond ? (n = 1) : n;
    cond ? (n = 1) : s.val;
    cond ? 1       : (n = 1);
    cond ? n       : (n = 1);
    cond ? s.val   : (n = 1);

    // errors
    cond ? 1     : 1;
    cond ? 1     : n;
    cond ? 1     : s.val;
    cond ? n     : 1;
    cond ? s.val : 1;
}
