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
