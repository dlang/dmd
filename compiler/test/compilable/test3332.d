// https://issues.dlang.org/show_bug.cgi?id=3332

template C ()
{
    this (int i)
    {
    }
}

class A
{
    mixin C f;
    this ()
    {
    }
    alias __ctor = f.__ctor;
}

void main ()
{
    auto a = new A(3);
}
