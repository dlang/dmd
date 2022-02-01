// https://issues.dlang.org/show_bug.cgi?id=22700

module issue22700;

void test8765(string msg, int a)
{
    assert(a);
    assert(msg == "0 != true");
}
