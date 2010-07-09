
class X(T:Policy!(T), alias Policy)
{
    mixin Policy!(T);
}

template MYP(T)
{
    void foo(T);
}

X!( MYP!(int) ) x;
