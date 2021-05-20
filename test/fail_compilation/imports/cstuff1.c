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
