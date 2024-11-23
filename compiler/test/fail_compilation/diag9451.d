/*
TEST_OUTPUT:
---
fail_compilation/diag9451.d(39): Error: cannot create instance of abstract class `C2`
    auto c2 = new C2;
              ^
fail_compilation/diag9451.d(33):        class `C2` is declared here
class C2 : C1
^
fail_compilation/diag9451.d(27):        function `void f1()` is not implemented
    abstract void f1();
                  ^
fail_compilation/diag9451.d(28):        function `void f2(int)` is not implemented
    abstract void f2(int);
                  ^
fail_compilation/diag9451.d(29):        function `void f2(float) const` is not implemented
    abstract void f2(float) const;
                  ^
fail_compilation/diag9451.d(30):        function `int f2(float) pure` is not implemented
    abstract int f2(float) pure;
                 ^
---
*/

class C1
{
    abstract void f1();
    abstract void f2(int);
    abstract void f2(float) const;
    abstract int f2(float) pure;
}

class C2 : C1
{
}

void main()
{
    auto c2 = new C2;
}
