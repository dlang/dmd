class Base
{
    string f()
    {
        return "Base.f()";
    }
}
class Derived : Base
{
    string f()
    {
        return "Derived.f()";
    }
    string f() const
    {
        return "Derived.f() const";
    }
}
