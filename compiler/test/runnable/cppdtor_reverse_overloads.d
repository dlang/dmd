/*
On targets that group C++ virtual overloads in reverse order (MSVC), an overload inserted in front
of the destructor's reserved vtbl slot must move that slot too; otherwise the destructor later
overwrites the function that shifted into the old slot.
*/

template Prop(alias member) { alias p = member; }
template AliasSeq(T...) { alias AliasSeq = T; }

__gshared int destroyed;

// an overload set split by the destructor
extern(C++) class A
{
    int d() const { return 1; }
    ~this() { ++destroyed; }
    int d(int v) const { return v; }
}

// the alias analyzes the virtuals ahead of the destructor
extern(C++) class B
{
    alias props = AliasSeq!(Prop!disabled, Prop!flags);
    ~this() { ++destroyed; }
    bool disabled() const { return false; }
    void disabled(bool) {}
    int flags() const { return 2; }
}

extern(C++) final class C : B
{
    override int flags() const { return 3; }
}

void main()
{
    A a = new A;
    assert(a.d() == 1);
    assert(a.d(5) == 5);
    assert(destroyed == 0);
    destroy(a);
    assert(destroyed == 1);

    B b = new C;
    assert(b.flags() == 3);
    assert(!b.disabled());
    assert(destroyed == 1);
    destroy(b);
    assert(destroyed == 2);
}
