// https://issues.dlang.org/show_bug.cgi?id=10616
class A
{
    void foo() {}
}
class B(T) : T
{
    static if (is(B : A))
        override void foo() {}
}
alias BA = B!A;

////

class C : C.D
{
    static class D
    {
    }
}
