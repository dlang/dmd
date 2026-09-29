// https://github.com/dlang/dmd/issues/20031
// A C++ compiler need not emit the complete-object constructor of an abstract class; a D class
// deriving from it constructs its base subobject through the base-object constructor.
// EXTRA_CPP_SOURCES: test20031.cpp

extern(C++) abstract class C
{
    this();
    abstract void f();
    int i;
}

extern(C++) class D : C
{
    override void f()
    {
        assert(i == 5);
    }
}

void main()
{
    D d = new D();
    d.f();
}
