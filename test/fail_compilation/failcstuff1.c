// check the expression parser
/* TEST_OUTPUT
---
fail_compilation/failcstuff1.c(51): Error: attributes should be specified before the function definition
fail_compilation/failcstuff1.c(100): Error: no members for `enum E21962`
fail_compilation/failcstuff1.c(101): Error: no members for anonymous enum
fail_compilation/failcstuff1.c(152): Error: `;` or `,` expected
fail_compilation/failcstuff1.c(153): Error: `void` has no value
fail_compilation/failcstuff1.c(153): Error: missing comma
fail_compilation/failcstuff1.c(153): Error: `;` or `,` expected
fail_compilation/failcstuff1.c(154): Error: empty struct-declaration-list for `struct Anonymous`
fail_compilation/failcstuff1.c(157): Error: identifier not allowed in abstract-declarator
fail_compilation/failcstuff1.c(203): Error: storage class not allowed in specifier-qualified-list
fail_compilation/failcstuff1.c(204): Error: storage class not allowed in specifier-qualified-list
fail_compilation/failcstuff1.c(205): Error: storage class not allowed in specifier-qualified-list
fail_compilation/failcstuff1.c(206): Error: storage class not allowed in specifier-qualified-list
fail_compilation/failcstuff1.c(207): Error: storage class not allowed in specifier-qualified-list
fail_compilation/failcstuff1.c(208): Error: storage class not allowed in specifier-qualified-list
fail_compilation/failcstuff1.c(251): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(252): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(253): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(258): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(259): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(260): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(301): Error: illegal type combination
fail_compilation/failcstuff1.c(352): Error: found `2` when expecting `:`
fail_compilation/failcstuff1.c(352): Error: found `:` instead of statement
fail_compilation/failcstuff1.c(403): Error: left operand is not assignable
fail_compilation/failcstuff1.c(404): Error: left operand is not assignable
fail_compilation/failcstuff1.c(405): Error: increment operand is not assignable
fail_compilation/failcstuff1.c(406): Error: decrement operand is not assignable
fail_compilation/failcstuff1.c(407): Error: increment operand is not assignable
fail_compilation/failcstuff1.c(408): Error: decrement operand is not assignable
fail_compilation/failcstuff1.c(409): Error: cannot take address of unary operand
fail_compilation/failcstuff1.c(453): Error: increment operand is not assignable
fail_compilation/failcstuff1.c(454): Error: decrement operand is not assignable
fail_compilation/failcstuff1.c(600): Error: `enum ENUM` has no members
---
*/

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=21937
#line 50
void test21962() __attribute__((noinline))
{
}

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=21962
#line 100
enum E21962 { };
enum { };

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=22028
#line 150
struct S22028
{
    int init = 1;
    void vfield nocomma;
    struct { };
};

int test22028 = sizeof(struct S22028 ident);

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=22029
#line 200
struct S22029
{
    int field;
    typedef int tfield;
    extern int efield;
    static int sfield;
    _Thread_local int lfield;
    auto int afield;
    register int rfield;
};

// https://issues.dlang.org/show_bug.cgi?id=22030
#line 250
int;
int *;
int &;
int , int;

struct S22030
{
    int;
    int *;
    int &;
    int, int;
    int _;
};

void test22030(struct S22030, struct S22030*, struct S22030[4]);

// https://issues.dlang.org/show_bug.cgi?id=22032
#line 300
struct S22032 { int field; }
int test22032;

// https://issues.dlang.org/show_bug.cgi?id=22035
#line 350
void test22035()
{
    case 1 2:
}

// https://issues.dlang.org/show_bug.cgi?id=22067
#line 400
void test22067()
{
    int var;
    (int) var = 1;
    sizeof(var) = 2;
    ++(short)3;
    --4;
    (5)++;
    ((int)var)--;
    (&6);
}

// https://issues.dlang.org/show_bug.cgi?id=22068
#line 450
void test22068()
{
    int var;
    ++(short) var;
    --(long long) var;
}

// https://issues.dlang.org/show_bug.cgi?id=22086
#line 500
typedef union U22086 U22086;

#line 600
enum ENUM;
