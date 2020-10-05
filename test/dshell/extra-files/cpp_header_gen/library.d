module library;

extern (C++):

int foo(ref const S s)
{
    return s.i;
}

int bar(const C c)
{
    return c.s.i;
}

/*
// TODO: Seems not implemented yet
interface I
{
    void verify();
}
*/

class C // : I
{
    S s;
    char[] name;

    extern(D) this(ref S s, char[] name)
    {
        this.s = s;
        this.name = name;
    }

    static C create(char* name, const int length)
    {
        auto s = S(length, length & 1);
        return new C(s, name[0 .. length]);
    }

    void verify()
    {
        assert(s.i == 6);
        assert(!s.b);
        assert(name == "Header");
    }
}

struct S
{
    int i;
    bool b = true;

    void multiply(ref const S other)
    {
        i *= other.i;
        b = b || !other.b;
    }
}

union U
{
    int a;
    bool b;
}

void toggle(ref U u)
{
    u.b = !u.b;
}

// FIXME: Generates non-existant global
// enum PI = 3.141; // extern _d_double PI;

__gshared const PI = 3.141;
__gshared int counter = 42;

enum Weather
{
    Sun,
    Rain,
    Storm
}

static if (true)
{
    struct S2
    {
        S s;
    }
}

alias AliasSeq(T...) = T;

__gshared AliasSeq!(int, double) globalTuple = AliasSeq!(3, 4.0);

void tupleFunction(AliasSeq!(int, double) argTuple)
{
    assert(argTuple[0] == 5);
    assert(argTuple[1] == 6.0);
}

struct WithTuple
{
    AliasSeq!(int, double) memberTuple;
}

WithTuple createTuple()
{
    return WithTuple(1, 2.0);
}
