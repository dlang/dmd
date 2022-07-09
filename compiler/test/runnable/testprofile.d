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
    do { }
}

// ------------------

class C10953
{
    void func() nothrow pure @safe
    in {} out {} do {}
}
class D10953 : C10953
{
    override void func()    // inherits attributes of Foo.func
    in {} out {} do {}
}

// ------------------

void test13331() {asm {naked; ret;}}

// ------------------

// https://issues.dlang.org/show_bug.cgi?id=15745

ubyte LS1B(uint board)
{
    asm
    {
        bsf EAX, board;
    }
}

void test15754()
{

    for (int i = 0; i < 31; ++i)
    {
        auto slide = (1U << i);
        auto ls1b = slide.LS1B;
        assert(ls1b == i);
    }
}

// ------------------

int main()
{
    test1();
    test5689();
    test13331();
    test15754();
    return 0;
}
