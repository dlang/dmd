/* REQUIRED_ARGS: -verrors=0
TEST_OUTPUT:
---
fail_compilation/diag9679.d(15): Error: variable `diag9679.main.n` - storage class `auto` has no effect if type is not inferred, did you mean `scope`?
fail_compilation/diag9679.d(16): Error: variable `diag9679.main.S.a` - field declarations cannot be `ref`
fail_compilation/diag9679.d(23): Error: returning `r` escapes a reference to local variable `r`
fail_compilation/diag9679.d(30): Error: returning `r` escapes a reference to local variable `r`
---
*/


void main()
{
    if (ref n = 1) {}
    if (auto int n = 1) {}
    struct S { ref int a; }
}

ref int test2()
{
    int i;
    ref r = i;
    return r;
}

ref int test3()
{
    extern int i;
    ref r = i;
    return r;
}

struct S { int a; }

void test4()
{
    S s;
    ref int r1 = s.a;
    r1 = 3;
    __gshared S t2;
    ref int r2 = t2.a;
    static S t3;
    ref int r3 = t3.a;
    extern S t4;
    ref int r4 = t4.a;
}

/* TEST_OUTPUT:
---
fail_compilation/diag9679.d(55): Error: variable `diag9679.test5.r5` - initializer is required for `ref` variable
---
*/
void test5()
{
    ref int r5;
}

