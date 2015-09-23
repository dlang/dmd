/**
 * This module contains tests which only work with RTTI enabled
 * and should produce certain compiler (as opposed to link) errors
 * when compiled with -betterC.
 *
 * This produces slighly different errors depending on whether the
 * druntime contains TypeInfo declarations.
 */
module nortti;

//----------------------------------------------------------------------

void function1()
{
    // This only fails for the miniRT version
    alias A = typeof(typeid(int));
}

//----------------------------------------------------------------------

void function2()
{
    // This always fails
    auto a = typeid(int);
}

//----------------------------------------------------------------------

struct SPostblit
{
    this(this)
    {
    }
}

void function3()
{
    SPostblit[4] sarr;
    SPostblit post;
    sarr[0..3] = post;
}

//----------------------------------------------------------------------

struct TestStruct
{
}

void function4()
{
    auto s = new TestStruct();
}

//----------------------------------------------------------------------

class TestClass
{
}

void function5()
{
    auto c = new TestClass();
}
