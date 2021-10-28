// https://issues.dlang.org/show_bug.cgi?id=16215

class Base
{
    class BaseInner {}
}

final class Derived: Base
{
    bool someMethod() { return false; }

    final class DerivedInner: BaseInner
    {
     	 void func()
         {
             someMethod();
         }
    }
}

class Foo
{
    class FooInner {}
}

class Bar: Foo
{
    byte foo;
    class BarInner(T): Foo.FooInner
    {
        byte zoo()
        {
            return foo;
        }
    }
    alias BarInnerThis = BarInner!Bar;
}
