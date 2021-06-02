module library;

version (D_ObjectiveC)
    import core.attribute : selector;

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

extern(C++) class VTable
{
    extern(D) int hidden_1() { return 1; }
    int callable_2() { return 2; }
    version (D_ObjectiveC)
        extern(Objective-C) int hidden_3() @selector("hidden_3") { return 3; }
    int callable_4() { return 4; }
    extern(D) final int hidden_5() { return 5; }
    int callable_6() { return 6; }
}

extern(C++) __gshared VTable vtable = new VTable();

extern(C++) struct TemplatedStruct(T)
{
    T t;
    this(T t) { this.t = t; }
}

alias Templated = TemplatedStruct;

extern(C++) Templated!int templated(Templated!(Templated!int) i)
{
    return typeof(return)(i.t.t);
}

inout(int)* inoutFunc(inout int* ptr)
{
    return ptr;
}

enum Pass
{
    inline = 10
}

struct InvalidNames(typename)
{
    typename register;

    void foo(typename and)
    {
        assert(register == and);
    }
}

void useInvalid(InvalidNames!Pass) {}
