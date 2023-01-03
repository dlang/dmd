// https://issues.dlang.org/show_bug.cgi?id=23279
/*
TEST_OUTPUT:
---
fail_compilation/ice23279.d(14): Error: undefined identifier `Sth`
fail_compilation/ice23279.d(19): Error: undefined identifier `Sth`
---
*/
module ice23279;

class Tester
{
    enum a = __traits(hasMember, Tester, "setIt");
    void setIt(Sth sth){}
}

class NotForward
{
    void setIt(Sth sth){}
    enum a = __traits(hasMember, NotForward, "setIt");
}
