/*
TEST_OUTPUT:
---
fail_compilation/fail142.d(27): Error: cannot create instance of abstract class `B`
    B b = new B();
          ^
fail_compilation/fail142.d(21):        class `B` is declared here
class B : A
^
fail_compilation/fail142.d(18):        function `void test()` is not implemented
    abstract void test() {}
                  ^
---
*/

class A
{
    abstract void test() {}
}

class B : A
{
}

void main()
{
    B b = new B();
}
