// check semantic analysis of C files
/* TEST_OUTPUT:
---
fail_compilation/failcstuff2.c(137): Error: cannot modify expression `cast(int)var` because it is not an lvalue
    (int) var = 1;
    ^
fail_compilation/failcstuff2.c(138): Error: `sizeof` is not a member of `int`
    sizeof(var) = 2;
           ^
fail_compilation/failcstuff2.c(139): Error: cannot modify expression `cast(short)3` because it is not an lvalue
    ++(short)3;
             ^
fail_compilation/failcstuff2.c(140): Error: cannot modify constant `4`
    --4;
      ^
fail_compilation/failcstuff2.c(141): Error: cannot modify constant `5`
    (5)++;
     ^
fail_compilation/failcstuff2.c(142): Error: cannot take address of constant `6`
    (&6);
      ^
fail_compilation/failcstuff2.c(143): Error: cannot modify expression `cast(int)var` because it is not an lvalue
    ((int)var)++;
     ^
fail_compilation/failcstuff2.c(144): Error: cannot modify expression `cast(int)var` because it is not an lvalue
    ((int)var)--;
     ^
fail_compilation/failcstuff2.c(145): Error: cannot modify expression `cast(int)var` because it is not an lvalue
    ++(int)var;
      ^
fail_compilation/failcstuff2.c(146): Error: cannot modify expression `cast(int)var` because it is not an lvalue
    --(int)var;
      ^
fail_compilation/failcstuff2.c(147): Error: cannot take address of expression `cast(int)var` because it is not an lvalue
    &(int)var;
     ^
fail_compilation/failcstuff2.c(148): Error: cannot take address of expression `makeS22067().field` because it is not an lvalue
    &makeS22067().field;
               ^
fail_compilation/failcstuff2.c(149): Error: cannot modify expression `makeS22067().field` because it is not an lvalue
    makeS22067().field = 1;
              ^
fail_compilation/failcstuff2.c(150): Error: cannot modify expression `makeS22067().field` because it is not an lvalue
    makeS22067().field++;
              ^
fail_compilation/failcstuff2.c(151): Error: cannot modify expression `makeS22067().field` because it is not an lvalue
    --makeS22067().field;
                ^
fail_compilation/failcstuff2.c(160): Error: cannot modify expression `cast(short)var` because it is not an lvalue
    ++(short) var;
              ^
fail_compilation/failcstuff2.c(161): Error: cannot modify expression `cast(long)var` because it is not an lvalue
    --(long long) var;
                  ^
fail_compilation/failcstuff2.c(185): Error: variable `arr` cannot be read at compile time
    int arr2[] = arr;
                 ^
fail_compilation/failcstuff2.c(191): Error: variable `str` cannot be read at compile time
    char msg[] = str;
                 ^
fail_compilation/failcstuff2.c(198): Error: cannot take address of register variable `reg1`
    int *ptr1 = &reg1;
                ^
fail_compilation/failcstuff2.c(201): Error: cannot take address of register variable `reg2`
    int *ptr2 = &reg2;
                ^
fail_compilation/failcstuff2.c(204): Error: cannot take address of register variable `reg3`
    int *ptr3 = (int *)reg3;
                       ^
fail_compilation/failcstuff2.c(205): Error: cannot index through register variable `reg3`
    int idx3a = reg3[0];
                    ^
fail_compilation/failcstuff2.c(206): Error: cannot take address of register variable `reg3`
    int idx3b = *reg3;
                 ^
fail_compilation/failcstuff2.c(207): Error: cannot take address of register variable `reg3`
    int idx3c = reg3 + 0;
                ^
fail_compilation/failcstuff2.c(208): Error: cannot index through register variable `reg3`
    int idx3d = 0[reg3];
                 ^
fail_compilation/failcstuff2.c(219): Error: cannot take address of register variable `reg4`
    int *ptr4a = &(reg4.inner.i);
                 ^
fail_compilation/failcstuff2.c(220): Error: cannot take address of register variable `reg4`
    int *ptr4b = reg4.inner.a;
                 ^
fail_compilation/failcstuff2.c(221): Error: cannot take address of register variable `reg4`
    int *ptr4c = (int*)reg4.inner.a;
                       ^
fail_compilation/failcstuff2.c(222): Error: cannot take address of bit-field `b`
    int *ptr4d = &(reg4.inner.b);
                 ^
fail_compilation/failcstuff2.c(223): Error: cannot index through register variable `reg4`
    int idx4a = reg4.inner.a[0];
                            ^
fail_compilation/failcstuff2.c(224): Error: cannot index through register variable `reg4`
    int idx4b = 0[reg4.inner.a];
                 ^
fail_compilation/failcstuff2.c(227): Error: cannot take address of register variable `reg5`
    int **ptr5 = &reg5;
                 ^
---
*/

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22069
// Line 50 starts here
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
// Line 100 starts here
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
// Line 150 starts here
void test22068()
{
    int var;
    ++(short) var;
    --(long long) var;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22405
// Line 300 starts here
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
// Line 350 starts here

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
// Line 350 starts here
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
