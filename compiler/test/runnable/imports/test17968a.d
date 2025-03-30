struct S(T)
{
    T t;
}

class C(T) { }

auto fun1(T)(T t)
{
    return S!T(t);
}

auto fun2()
{
    return new C!int;
}
