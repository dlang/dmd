// REQUIRED_ARGS: -profile

module testprofile;

// ------------------

struct FourUShort {
    this(ushort a, ushort b, ushort c, ushort d) {
        this.a = a;
        this.b = b;
        this.c = c;
        this.d = d;
    }
    ushort a, b, c, d;
}

void test1()
{
    auto f = FourUShort(0, 1, 2, 3);
    assert(f.a == 0);
    assert(f.b == 1);
    assert(f.c == 2);
    assert(f.d == 3);
}

// ------------------

void foo5689(double a, double b)
{
    assert(a == 17.0);
    assert(b == 12.0);
}

__gshared fun5689 = &foo5689;

void test5689()
{
    fun5689(17.0, 12.0);
}

// ------------------

class Foo10617
{
    void foo() nothrow pure @safe
    in { }
    out { }
    body { }
}

// ------------------

class C10953
{
    void func() nothrow pure @safe
    in {} out {} body {}
}
class D10953 : C10953
{
    override void func()    // inherits attributes of Foo.func
    in {} out {} body {}
}

// ------------------

void test13331() {asm {naked; ret;}}

// ------------------

void main()
{
    test1();
    test5689();
    test13331();
}
