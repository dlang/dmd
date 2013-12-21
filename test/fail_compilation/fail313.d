/*
TEST_OUTPUT:
---
fail_compilation/fail313.d(15): Error: function fail313.Derived.str return type inference is not supported if may override base class function
---
*/

class Base
{
    abstract int str();
}

class Derived : Base
{
    override str()
    {
        return "string";
    }
}
