// check the expression parser

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=21937
#line 100
void test21962() __attribute__((noinline))
{
}

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=21962
#line 200
enum E21962 { };
enum { };

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=22028
#line 250
struct S22028
{
    int init = 1;
    void vfield nocomma;
    struct { };
};

int test22028 = sizeof(struct S22028 ident);

/********************************/
// https://issues.dlang.org/show_bug.cgi?id=22029
#line 300
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
#line 400
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
#line 450
struct S22032 { int field; }
int test22032;

// https://issues.dlang.org/show_bug.cgi?id=22035
#line 500
void test22035()
{
    case 1 2:
}

// https://issues.dlang.org/show_bug.cgi?id=22068
#line 600
void test22068()
{
    int var;
    ++(short) var;
    --(long long) var;
}
