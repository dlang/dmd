/*
TEST_OUTPUT:
---
fail_compilation/issue3396.d(19): Error: call to unimplemented abstract function `void M()`
    override void M(){ super.M(); }
                              ^
fail_compilation/issue3396.d(19):        declared here: fail_compilation/issue3396.d(14)
---
*/
module issue3396;

abstract class A
{
    abstract void M();
}

class B:A
{
    override void M(){ super.M(); }
}

void test()
{
    auto b=new B();
    b.M();
}
