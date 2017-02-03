class Base
{
    this() shared
    {}

    this()
    {}
}

class Derived : Base
{
    this()
    {
        // implicit super();
    }
}
