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
fail_compilation/failcstuff2.c(204): Error: variable `var` is used as a type
fail_compilation/failcstuff2.c(203):        variable `var` is declared here
fail_compilation/failcstuff2.c(205): Error: variable `var` is used as a type
fail_compilation/failcstuff2.c(203):        variable `var` is declared here
fail_compilation/failcstuff2.c(254): Error: identifier or `(` expected before `)`
fail_compilation/failcstuff2.c(255): Error: identifier or `(` expected
fail_compilation/failcstuff2.c(308): Error: cannot modify `const` expression `(*s).p`
fail_compilation/failcstuff2.c(354): Error: variable `arr` cannot be read at compile time
fail_compilation/failcstuff2.c(360): Error: variable `str` cannot be read at compile time
fail_compilation/failcstuff2.c(404): Error: undefined identifier `p1`
fail_compilation/failcstuff2.c(404): Error: undefined identifier `p2`
fail_compilation/failcstuff2.c(458): Error: cannot take address of bit-field `field`
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

#line 200
/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21992
void test21992(int var)
{
    var = (var) ~ 1234;
    var = (var) ! 1234;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22102
#line 250
typedef int int22102;

void test22102()
{
    int22102();
    int22102(0);
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
// https://issues.dlang.org/show_bug.cgi?id=22584
#line 400
long test22584(long p1, long p2);

long test22584(long, long)
{
    return p1 + p2;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22749
#line 450
struct S22749
{
    int field : 1;
};

void test22749(void)
{
    struct S22749 s;
    void *ptr = &s.field;
}
