/*******************************************/
// https://issues.dlang.org/show_bug.cgi?id=18828

struct S18828 { }

void test18828()
{
    S18828 s;
    destroy(s);
}
