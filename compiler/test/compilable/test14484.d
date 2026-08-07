// https://issues.dlang.org/show_bug.cgi?id=14484

class A
{
    final void f(this This)()
    {
        static assert(This.stringof == "B");
    }
}

class B : A
{
    void x()
    {
        f();
    }
}
