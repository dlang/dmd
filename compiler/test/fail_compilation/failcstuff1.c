// check the expression parser
/* TEST_OUTPUT:
---
fail_compilation/failcstuff1.c(184): Error: no members for `enum E21962`
enum E21962 { };
              ^
fail_compilation/failcstuff1.c(185): Error: no members for anonymous enum
enum { };
       ^
fail_compilation/failcstuff1.c(192): Error: `;` or `,` expected
    int init = 1;
             ^
fail_compilation/failcstuff1.c(193): Error: `void` has no value
    void vfield nocomma;
                ^
fail_compilation/failcstuff1.c(193): Error: missing comma
    void vfield nocomma;
                ^
fail_compilation/failcstuff1.c(193): Error: `;` or `,` expected
    void vfield nocomma;
                ^
fail_compilation/failcstuff1.c(197): Error: expression expected, not `struct`
int test22028 = sizeof(struct S22028 ident);
                       ^
fail_compilation/failcstuff1.c(197): Error: found `S22028` when expecting `)`
int test22028 = sizeof(struct S22028 ident);
                              ^
fail_compilation/failcstuff1.c(197): Error: missing comma or semicolon after declaration of `test22028`, found `ident` instead
int test22028 = sizeof(struct S22028 ident);
                                     ^
fail_compilation/failcstuff1.c(205): Error: storage class not allowed in specifier-qualified-list
    typedef int tfield;
                ^
fail_compilation/failcstuff1.c(206): Error: storage class not allowed in specifier-qualified-list
    extern int efield;
               ^
fail_compilation/failcstuff1.c(207): Error: storage class not allowed in specifier-qualified-list
    static int sfield;
               ^
fail_compilation/failcstuff1.c(208): Error: storage class not allowed in specifier-qualified-list
    _Thread_local int lfield;
                      ^
fail_compilation/failcstuff1.c(209): Error: storage class not allowed in specifier-qualified-list
    auto int afield;
             ^
fail_compilation/failcstuff1.c(210): Error: storage class not allowed in specifier-qualified-list
    register int rfield;
                 ^
fail_compilation/failcstuff1.c(216): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(216): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(216): Error: expected identifier for declaration
fail_compilation/failcstuff1.c(217): Error: identifier or `(` expected
int &;
    ^
fail_compilation/failcstuff1.c(217): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(217): Error: expected identifier for declaration
fail_compilation/failcstuff1.c(218): Error: identifier or `(` expected
int , int;
    ^
fail_compilation/failcstuff1.c(218): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(218): Error: expected identifier for declaration
fail_compilation/failcstuff1.c(223): Error: identifier or `(` expected
fail_compilation/failcstuff1.c(223): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(224): Error: identifier or `(` expected
    int &;
        ^
fail_compilation/failcstuff1.c(224): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(225): Error: identifier or `(` expected
    int, int;
       ^
fail_compilation/failcstuff1.c(225): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(234): Error: illegal type combination
int test22032;
    ^
fail_compilation/failcstuff1.c(240): Error: found `2` when expecting `:`
    case 1 2:
           ^
fail_compilation/failcstuff1.c(240): Error: found `:` instead of statement
fail_compilation/failcstuff1.c(249): Error: static array parameters are not supported
void test22103a(int array[4][static 4]);
                                      ^
fail_compilation/failcstuff1.c(249): Error: static or type qualifier used in non-outermost array type derivation
void test22103a(int array[4][static 4]);
                                      ^
fail_compilation/failcstuff1.c(250): Error: static or type qualifier used in non-outermost array type derivation
void test22103b(int array[4][restrict]);
                                      ^
fail_compilation/failcstuff1.c(250): Error: array type has incomplete element type `int[0]`
void test22103b(int array[4][restrict]);
                                      ^
fail_compilation/failcstuff1.c(251): Error: array type has incomplete element type `int[0]`
void test22103c(int array[4][]);
                              ^
fail_compilation/failcstuff1.c(252): Error: array type has incomplete element type `int[0]`
void test22103d(int array[][]);
                             ^
fail_compilation/failcstuff1.c(253): Error: found `const` when expecting `,`
void test22103e(int array[4] const);
                             ^
fail_compilation/failcstuff1.c(257): Error: static array parameters are not supported
fail_compilation/failcstuff1.c(257): Error: static or type qualifier used outside of function prototype
fail_compilation/failcstuff1.c(258): Error: static or type qualifier used outside of function prototype
fail_compilation/failcstuff1.c(259): Error: variable length arrays are not supported
fail_compilation/failcstuff1.c(259): Error: variable length array used outside of function prototype
fail_compilation/failcstuff1.c(260): Error: array type has incomplete element type `int[0]`
fail_compilation/failcstuff1.c(261): Error: `=`, `;` or `,` expected to end declaration instead of `const`
    int array4[4] const;
                  ^
fail_compilation/failcstuff1.c(268): Error: no type-specifier for parameter
    int(0);
        ^
fail_compilation/failcstuff1.c(268): Error: found `0` when expecting `,`
    int(0);
        ^
fail_compilation/failcstuff1.c(268): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(270): Error: expected identifier for declarator
fail_compilation/failcstuff1.c(277): Error: missing comma or semicolon after declaration of `pluto`, found `p` instead
int * pluto p;
            ^
fail_compilation/failcstuff1.c(282): Error: `=`, `;` or `,` expected to end declaration instead of `'s'`
char c22909 = u8's';
                ^
fail_compilation/failcstuff1.c(288): Error: multiple storage classes in declaration specifiers
    static extern int aa;
           ^
fail_compilation/failcstuff1.c(289): Error: multiple storage classes in declaration specifiers
    static auto int ab;
           ^
fail_compilation/failcstuff1.c(290): Error: multiple storage classes in declaration specifiers
    static register int ac;
           ^
fail_compilation/failcstuff1.c(291): Error: multiple storage classes in declaration specifiers
    static typedef int ad;
           ^
fail_compilation/failcstuff1.c(292): Error: multiple storage classes in declaration specifiers
    extern auto int ah;
           ^
fail_compilation/failcstuff1.c(293): Error: multiple storage classes in declaration specifiers
    extern register int ai;
           ^
fail_compilation/failcstuff1.c(294): Error: multiple storage classes in declaration specifiers
    extern typedef int aj;
           ^
fail_compilation/failcstuff1.c(295): Error: multiple storage classes in declaration specifiers
    auto register int an;
         ^
fail_compilation/failcstuff1.c(296): Error: multiple storage classes in declaration specifiers
    auto typedef int ao;
         ^
fail_compilation/failcstuff1.c(297): Error: multiple storage classes in declaration specifiers
    auto _Thread_local int ar;
         ^
fail_compilation/failcstuff1.c(298): Error: multiple storage classes in declaration specifiers
    register typedef int as;
             ^
fail_compilation/failcstuff1.c(299): Error: multiple storage classes in declaration specifiers
    register _Thread_local int av;
             ^
fail_compilation/failcstuff1.c(300): Error: multiple storage classes in declaration specifiers
    typedef _Thread_local int ay;
            ^
fail_compilation/failcstuff1.c(302): Error: `inline` and `_Noreturn` function specifiers not allowed for `_Thread_local`
    inline _Thread_local int ba;
           ^
fail_compilation/failcstuff1.c(303): Error: `inline` and `_Noreturn` function specifiers not allowed for `_Thread_local`
    _Noreturn _Thread_local int bb;
              ^
fail_compilation/failcstuff1.c(323): Error: `auto` and `register` storage class not allowed for global
register char *stack_pointer;
^
---
*/

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=21937
// Line 50 starts here
void test21962() __attribute__((noinline))
{
}

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=21962
// Line 100 starts here
enum E21962 { };
enum { };

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=22028
// Line 150 starts here
struct S22028
{
    int init = 1;
    void vfield nocomma;
    struct { };
};

int test22028 = sizeof(struct S22028 ident);

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=22029
// Line 200 starts here
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
// Line 250 starts here
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
// Line 300 starts here
struct S22032 { int field; }
int test22032;

// https://issues.dlang.org/show_bug.cgi?id=22035
// Line 350 starts here
void test22035()
{
    case 1 2:
}

// https://issues.dlang.org/show_bug.cgi?id=21932
// Line 400 starts here
enum ENUM;

// https://issues.dlang.org/show_bug.cgi?id=22103
// Line 450 starts here
void test22103a(int array[4][static 4]);
void test22103b(int array[4][restrict]);
void test22103c(int array[4][]);
void test22103d(int array[][]);
void test22103e(int array[4] const);

void test22103e()
{
    int array1[static volatile 4];
    int array2[restrict 4];
    int array3[4][*];
    int array4[][];
    int array4[4] const;
}

// https://issues.dlang.org/show_bug.cgi?id=22102
// Line 500 starts here
void test22102()
{
    int(0);
    int var1;
    int();
    int var2;
}

/****************************************************/
// Line 550 starts here

int * pluto p;

// https://issues.dlang.org/show_bug.cgi?id=22909
// Line 600 starts here

char c22909 = u8's';

/****************************************************/
// Line 650 starts here
void testDeclSpec()
{
    static extern int aa;
    static auto int ab;
    static register int ac;
    static typedef int ad;
    extern auto int ah;
    extern register int ai;
    extern typedef int aj;
    auto register int an;
    auto typedef int ao;
    auto _Thread_local int ar;
    register typedef int as;
    register _Thread_local int av;
    typedef _Thread_local int ay;
    // Mixing function-specifiers with _Thread_local
    inline _Thread_local int ba;
    _Noreturn _Thread_local int bb;
    // Valid code as per C11 spec
    static _Thread_local int ag;
    extern _Thread_local int am;
    // Mixing declaration and function specifiers meaningless, but ignored.
    static inline int ae;
    static _Noreturn int af;
    extern inline int ak;
    extern _Noreturn int al;
    auto inline int ap;
    auto _Noreturn int aq;
    register inline int at;
    register _Noreturn int au;
    typedef inline int aw;
    typedef _Noreturn int ax;
    inline _Noreturn int az;
}

/****************************************************/
// Line 700 starts here
register char *stack_pointer;
