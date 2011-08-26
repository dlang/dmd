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

void main()
{
    test1();
}
