// check semantic analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff2.c(54): Error: `& var` has no effect
fail_compilation/failcstuff2.c(55): Error: `*ptr` has no effect
fail_compilation/failcstuff2.c(56): Error: `var` has no effect
fail_compilation/failcstuff2.c(57): Error: `-var` has no effect
fail_compilation/failcstuff2.c(58): Error: `~var` has no effect
fail_compilation/failcstuff2.c(59): Error: `!var` has no effect
fail_compilation/failcstuff2.c(113): Error: `cast(int)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(114): Error: cannot modify constant `var.sizeof`
fail_compilation/failcstuff2.c(115): Error: `cast(short)3` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(116): Error: cannot modify constant `4`
fail_compilation/failcstuff2.c(117): Error: cannot modify constant `5`
fail_compilation/failcstuff2.c(118): Error: cannot modify constant `6`
fail_compilation/failcstuff2.c(119): Error: `cast(int)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(120): Error: `cast(int)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(121): Error: `cast(int)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(122): Error: `cast(int)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(123): Error: `cast(int)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(124): Error: `makeS22067().field` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(125): Error: `makeS22067().field` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(126): Error: `makeS22067().field` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(127): Error: `makeS22067().field` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(153): Error: `cast(short)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(154): Error: `cast(long)var` is not an lvalue and cannot be modified
---
*/

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22069
#line 50
void test22069()
{
    int var;
    int *ptr;
    &var;
    *ptr;
    +var;
    -var;
    ~var;
    !var;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22067
#line 100
struct S22067
{
    int field;
};

struct S22067 makeS22067()
{
    return (struct S22067) { 42 };
}

void test22067()
{
    int var;
    (int) var = 1;
    sizeof(var) = 2;
    ++(short)3;
    --4;
    (5)++;
    (&6);
    ((int)var)++;
    ((int)var)--;
    ++(int)var;
    --(int)var;
    &(int)var;
    &makeS22067().field;
    makeS22067().field = 1;
    makeS22067().field++;
    --makeS22067().field;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22068
#line 150
void test22068()
{
    int var;
    ++(short) var;
    --(long long) var;
}
