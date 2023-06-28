// check semantic analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff2.c(113): Error: `cast(int)var` is not an lvalue and cannot be modified
fail_compilation/failcstuff2.c(114): Error: `sizeof` is not a member of `int`
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
fail_compilation/failcstuff2.c(354): Error: variable `arr` cannot be read at compile time
fail_compilation/failcstuff2.c(360): Error: variable `str` cannot be read at compile time
fail_compilation/failcstuff2.c(352): Error: cannot take address of register variable `reg1`
fail_compilation/failcstuff2.c(355): Error: cannot take address of register variable `reg2`
fail_compilation/failcstuff2.c(358): Error: cannot take address of register variable `reg3`
fail_compilation/failcstuff2.c(359): Error: cannot index through register variable `reg3`
fail_compilation/failcstuff2.c(360): Error: cannot take address of register variable `reg3`
fail_compilation/failcstuff2.c(361): Error: cannot take address of register variable `reg3`
fail_compilation/failcstuff2.c(362): Error: cannot index through register variable `reg3`
fail_compilation/failcstuff2.c(373): Error: cannot take address of register variable `reg4`
fail_compilation/failcstuff2.c(374): Error: cannot take address of register variable `reg4`
fail_compilation/failcstuff2.c(375): Error: cannot take address of register variable `reg4`
fail_compilation/failcstuff2.c(376): Error: cannot take address of bit-field `b`
fail_compilation/failcstuff2.c(377): Error: cannot index through register variable `reg4`
fail_compilation/failcstuff2.c(378): Error: cannot index through register variable `reg4`
fail_compilation/failcstuff2.c(381): Error: cannot take address of register variable `reg5`
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

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22405
#line 300
struct S22405
{
    int * const p;
    int *q;
};

void test22405(struct S22405 *s)
{
    s->p = (const int *)(s->q);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22413
#line 350

void test22413a()
{
    int arr[6] = {1,2,3,4,5,6};
    int arr2[] = arr;
}

void test22413b()
{
    const char *str = "hello";
    char msg[] = str;
}

/***************************************************/
#line 350
void testRegister(register int reg1)
{
    int *ptr1 = &reg1;

    register int reg2;
    int *ptr2 = &reg2;

    register int reg3[1];
    int *ptr3 = (int *)reg3;
    int idx3a = reg3[0];
    int idx3b = *reg3;
    int idx3c = reg3 + 0;
    int idx3d = 0[reg3];

    register struct
    {
        struct
        {
            int i;
            int b : 4;
            int a[1];
        } inner;
    } reg4;
    int *ptr4a = &(reg4.inner.i);
    int *ptr4b = reg4.inner.a;
    int *ptr4c = (int*)reg4.inner.a;
    int *ptr4d = &(reg4.inner.b);
    int idx4a = reg4.inner.a[0];
    int idx4b = 0[reg4.inner.a];

    register int *reg5;
    int **ptr5 = &reg5;
}
