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
// https://issues.dlang.org/show_bug.cgi?id=22160

typedef struct testcstuff2 testcstuff2;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22182

int test22182a(int x)
{
    return (int)(x);
}

typedef struct S22182 { int x; } S22182;

int test22182b(S22182* b)
{
    return ((S22182*)(b))->x;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22196

__attribute__((static, unsigned, long, const, extern, register, typedef, short,
               inline, _Noreturn, volatile, signed, auto, restrict, _Complex,
               _Thread_local, int, char, float, double, void, _Bool, _Atomic))
int test22196();

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22245

struct S22245 { int i; };

int test22245()
{
    struct S22245 s;
    return sizeof(s.i);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22262

void test22262(unsigned char *buf)
{
    if (buf == 0)
        return;
    if (0 == buf)
        return;
    if (buf == 1)
        return;
    if (2 == buf)
        return;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22264

typedef int T22264;

unsigned long test22264(crc, buf, len)
    unsigned long crc;
    const T22264 *buf;
    T22264 len;
{
    return len;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22274

void test22274(compr, comprLen, uncompr, uncomprLen)
    unsigned *compr, *uncompr;
    signed comprLen, uncomprLen;
{
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22375

typedef struct S22375S
{
    unsigned short a, b, c, d;
} S22375;

static const S22375 s22375[10] =
{
    {0, 0, 0, 0},
    {4, 4, 8, 4},
    {4, 5, 16, 8},
    {4, 6, 32, 32},
    {4, 4, 16, 16},
    {8, 16, 32, 32},
    {8, 16, 128, 128},
    {8, 32, 128, 256},
    {32, 128, 258, 1024},
    {32, 258, 258, 4096}
};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22399

struct S22399a
{
    unsigned short f1;
};

struct S22399b
{
    const struct S22399a *f1;
};

const struct S22399a C22399[1] = { {12} };
const struct S22399b C22399b = {C22399};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22400

typedef struct S22400
{
    unsigned short f1;
} S22400_t;

struct S22400b
{
    const S22400_t *f1;
};

const S22400_t C22400[1] = { {12} };
const struct S22400b C22400b = {C22400};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22402

typedef struct {
    short c;
} S22402a;

typedef struct {
    S22402a *a;
    S22402a b[1];
} S22402b;

int test22402a(S22402a *a, S22402a b[1])
{
    return a - b;
}

int test22402b(S22402b *s)
{
    return s->a - s->b;
}

int test22402c(S22402a *a)
{
    S22402a b[1];
    return a - b;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22403

extern unsigned test22403a(const char *p);

void test22403()
{
    test22403a(0);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22404

typedef enum
{
    E22404_FLAG
} E22404;

int test22404a(E22404 e);

int test22404()
{
    test22404a(E22404_FLAG);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22405

struct S22405
{
    int const * p;
    int *q;
};

void test22405(struct S22405 *s)
{
    s->p = (const int *)(s->q);
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22406

int test22406(int a)
{
    switch (a)
    {
        case 1: return -1;
        case 2: return -2;
        case 3: return -3;
    }
    return 0;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22407

typedef int (*T22407) (int a);

int test22407(int a);

T22407 table22407[1] = { test22407 };

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22409

struct S22409;

typedef struct S22409
{
    int f1;
} S22409_t;

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22411

extern char * const var22411[10];

void test22411()
{
    char *cptr;
    int *iptr;
    float *fptr;
    struct { int f1; int f2; } *sptr;
    void (*fnptr)(void);

    cptr = var22411[0];
    iptr = var22411[1];
    fptr = var22411[2];
    sptr = var22411[3];
    fnptr = var22411[4];

    iptr = cptr;
    fptr = sptr;
    fnptr = iptr;
    cptr = fptr;
    sptr = fnptr;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22413

int test22413(void)
{
    char msg[] = "ok";
    return msg[0] | msg[1];
}

/***************************************************/

int test(char *dest)
{
    int x;
    return dest == x;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22512

extern char *tzname[];

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22584

long test22584(long, long);

long test22584(long a, long b)
{
    return a + b;
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22602

void test22602()
{
    unsigned char *data;
    data = (void *)"\0\0\xff\xff";
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22401

struct S22401
{
    const int *p;
};
const int c22401[1] = {0};
const struct S22401 d22401 = {c22401};

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22841

void test22841()
{
    int v22841;
    { unsigned v22841; }
}

/***************************************************/
// https://issues.dlang.org/show_bug.cgi?id=22961
int main(argc, argv)
        int argc;
        char **argv;
{
        return 0;
}

// https://issues.dlang.org/show_bug.cgi?id=23018

int xs[1];
struct { int x; } s, *sp;
int fn(void);
int i;

 _Static_assert( sizeof (xs)[0] == sizeof(int), "" );
 _Static_assert( sizeof (sp)->x == sizeof(int), "" );
_Static_assert( sizeof (s).x == sizeof(int), "" );
_Static_assert( sizeof (fn)() == sizeof(int), "" );
_Static_assert( sizeof (i)++ == sizeof(int), "" );
