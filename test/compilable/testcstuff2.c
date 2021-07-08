// check bugs in the expression parser

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21931

typedef long int T21931a;
typedef T21931a T21931b;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21933

struct S21933 { void *opaque; };
int test21933(struct S21933 *);

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21934

typedef int T21934 asm("realtype");
int init21934 asm("realsym") = 1;
int var21934 asm("realvsym");
int fun21934() asm("realfun");

void test21934()
{
    typedef int asmreg;
    register asmreg r1 asm("r1");
    // asm ignored by C compiler, should be disallowed?
    asmreg r2 asm("r2");

    register asmreg r3 asm("r3") = 3;
    // asm ignored by C compiler, should be disallowed?
    asmreg r4 asm("r4") = 4;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21937

__attribute__(()) int test21937a();
int test21937b() __attribute__(( , nothrow, hot, aligned(2), ));
int test21937c() __attribute__((nothrow , leaf)) __attribute__((noreturn));

__attribute__((noinline))
void test21937d()
{
    typedef int attr_var_t;
    attr_var_t attr_local __attribute__((unused));
}

__attribute__((aligned)) int test21937e;
int test21937f __attribute__((aligned));

struct __attribute__((packed)) S21937a
{
    __attribute__((deprecated("msg"))) char c;
    int i __attribute__((deprecated));
};

struct S21937b
{
    __attribute__((deprecated("msg"))) char c;
    int i __attribute__((deprecated));
} __attribute__((packed));

enum __attribute__((aligned)) E21937a
{
    E21937a_A,
};

enum E21937b
{
    E21937b_A,
} __attribute__((aligned));

typedef int T21937a __attribute__((unused));

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21945

typedef struct {
    long var;
} S21945;
S21945 test21945a;

typedef enum {
    E21945_member,
} E21945;
E21945 test21945b;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21948

void test21948()
{
    typedef int myint;
    typedef struct { int f; } mystruct;

    myint var1;
    myint var2 = 12;
    mystruct var3;
    // Uncomment when bug fixed https://issues.dlang.org/show_bug.cgi?id=21979
    //mystruct var4 = { 34 };
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21963

union U21963
{
    int iv;
    float fv;
};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21965

struct { int var; };
typedef struct { int var; };

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21967

const int test21967a(void);
const int *test21967b(void);

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21968

struct S21968
{
    struct inner *data[16];
};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21970

extern int test21970a;
extern char *test21970b;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21973

struct S21973
{
    int field;
    struct
    {
        int nested;
    };
};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21977
int test21977a;
_Thread_local int test21977b;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21982

struct S21982 { int field; };
struct S21982 test21982;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=21992

void test21992(int var)
{
    var = (var) & 1234;
    var = (var) * 1234;
    var = (var) + 1234;
    var = (var) - 1234;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22028

struct S22028
{
    struct nested
    {
        int field;
    };
    const int cfield;
    _Static_assert(1 == 1, "ok");
};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22060

struct S22060;
typedef struct S22060 T22060a;
struct S22060;
typedef struct S22060 T22060b;
struct S22060;
struct S22060
{
    int _flags;
};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22061

union S22061
{
    int field;
};
typedef union S22061 S22061;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22063

typedef struct S22063_t
{
    int field;
} S22063;

void test22063()
{
    // BUG: no definition of struct
    //struct S22063_t v1 = { 0 };
    // BUG: cannot implicitly cast from integer to pointer.
    struct S22063_t *v2 = (struct S22063_t *)0;
    S22063 v3 = { 0 };
    S22063 *v4 = (S22063 *)0;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22066

void test22066()
{
    int var = 0;
    (var)++;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22067

void test22067()
{
    union U {
        int value;
        char *ptr;
        char array[4];
    } var;
    union U *pvar = &var;
    var.value = 0xabcdef;
    var.array[0]++;
    (*var.ptr)--;
    ++(*pvar).value;
    --(*pvar).array[3];
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22073

struct S22073a { int field; };
struct S22073b { const char *field; };

_Static_assert((struct S22073a){6789}.field == 6789, "ok");
_Static_assert((struct S22073b){"zxcv"}.field[2] == 'c', "ok");

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22079

struct S22079
{
    int a, b, c;
};

_Static_assert(sizeof(struct S22079){1,2,3} == sizeof(int)*3, "ok");
_Static_assert(sizeof(struct S22079){1,2,3}.a == sizeof(int), "ok");

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22080

int F22080(const char *);

int test22080()
{
    int (*fun)(const char *) = &F22080;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22086
typedef union U22086 U22086;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22088

void test22088()
{
    int *p;
    int i;
    p = i;
    i = p;

    void *pv;
    p = pv;
    pv = p;

    long long ll;
    ll = i;
    i = ll;

    char c;
    c = i;
    i = c;

    float f;
    f = i;
    i = f;

    double d;
    d = i;
    i = d;

    long double ld;
    ld = i;
    i = ld;
    c = ld;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22102

void fun22102(int var);
typedef int int22102;

void test22102()
{
    int22102(var);
    fun22102(var);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22103

void test22103a(char *const argv[restrict]);
void test22103b(char *const argv[restrict 4]);

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22106

typedef struct S22106
{
    int field;
} S22106_t;

struct T22106
{
    struct S22106 f1;
    S22106_t f2;
};

void testS22106()
{
    struct S22106 v1;
    S22106_t v2;
}

int S22106; // not a redeclaration of 'struct S22106'

/***************************************************/
