// https://issues.dlang.org/show_bug.cgi?id=23569
// DISABLED: linux freebsd openbsd osx hurd dragonflybsd netbsd

extern(C++) class A
{
    ~this(){}
}

extern(C++) interface I
{
    void f();
}

extern(C++) class B : A, I
{
    int bField = 42;

    void f()
    {
        assert(bField == 42); // Verify the receiver is valid and points to the correct B object
        bField = 43; // Mark as called
    }
}

extern(C++) class C : B
{
    override void f()
    {
        super.f(); // Should call B.f directly and not recurse indefinitely
    }
}

void main()
{
    C c = new C();
    c.f();
    assert(c.bField == 43); // Ensure B.f was reached exactly once
}
