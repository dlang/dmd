/*
TEST_OUTPUT:
---
fail_compilation/ice15744.d(17): Error: overloadset ice15744.S.__ctor is aliased to a function
fail_compilation/ice15744.d(53): Error: template instance ice15744.S.AddField!string.__ctor!int error instantiating
fail_compilation/ice15744.d(41): Error: overloadset ice15744.B.__ctor is aliased to a function
fail_compilation/ice15744.d(54): Error: template instance ice15744.C.__ctor!(string, int) error instantiating
---
*/

template AddField(T)
{
    T b;
    this(Args...)(T b, auto ref Args args)
    {
        this.b = b;
        this(args);
    }
}

template construcotrs()
{
    int a;
    this(int a)
    {
        this.a = a;
    }
}

class B
{
    mixin construcotrs;
    mixin AddField!(string);
}

class C : B
{
    this(A...)(A args)
    {
        // The called super ctor is an overload set.
        super(args);
    }
}

struct S
{
    mixin construcotrs;
    mixin AddField!(string);
}

void main()
{
    auto s = S("bar", 15);
    auto c = new C("bar", 15);
}

// Note: This test case should be accepted finally. See issue 15784.
