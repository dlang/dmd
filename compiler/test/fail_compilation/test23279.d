// https://issues.dlang.org/show_bug.cgi?id=23279

/*
TEST_OUTPUT:
---
fail_compilation/test23279.d(15): Error: undefined identifier `Sth`
    void setIt(Sth sth){}
         ^
---
*/

class Tester
{
    enum a = __traits(hasMember, Tester, "setIt");
    void setIt(Sth sth){}
}
