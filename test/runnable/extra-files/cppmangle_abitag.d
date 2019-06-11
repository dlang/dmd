/*
 * Test C++ abi-tag name mangling.
 * https://issues.dlang.org/show_bug.cgi?id=19949
 */

extern(C++):

alias Tuple(A...) = A;
enum foo_bar = gnuAbiTag("foo", "bar");

// UDA
extern (D) struct gnuAbiTag
{
    string tag;
    string[] tags;

    @disable this();

    this(string tag, string[] tags...)
    {
        this.tag = tag;
        this.tags = tags;
    }
}

@foo_bar
struct S
{
    int i;
}

@foo_bar
extern __gshared int a;

extern __gshared S b;

@foo_bar
int f();

S gs(int);
S gss(S, int);

@foo_bar
S fss(S, int);

T gt(T)(int);
T gtt(T)(T, int);

@foo_bar
T ft(T)(int);

@foo_bar
T ftt(T)(T, int);

@gnuAbiTag("AAA") @("abc")
extern(C++, "N")
{
    @gnuAbiTag("foo")
    template K(int i)
    {
        @gnuAbiTag("bar")
        struct K
        {
            int i;
            this(int);
        }
    }
}

K!i fk(int i)(int);
K!1 fk1(int);

extern __gshared K!10 k10;

@gnuAbiTag("ENN")
enum E0 { a = 0xa, }
E0 fe();
E0 fei(int i)();

version (linux)
{
    // Linux std::string
    // https://issues.dlang.org/show_bug.cgi?id=14956#c13
    extern(C++, "std")
    {
        struct allocator(T);
        struct char_traits(CharT);

        @gnuAbiTag("cxx11")
        extern(C++,  "__cxx11")
        {
            struct basic_string(CharT, Traits=char_traits!CharT, Allocator=allocator!CharT)
            {
                const char* data();
                size_t length() const;
            }
        }
        alias string_ = basic_string!char;
    }
    string_* toString(const char*);
}

void initVars();

void main()
{
    initVars();
    assert(a == 10);
    assert(b.i == 20);
    assert(k10.i == 30);

    assert(f() == 0xf);
    assert(gs(1).i == 1+0xe0);
    assert(gss(S(1), 1).i == 2+0xe0);
    assert(fss(S(1), 1).i == 2+0xf);
    assert(gt!S(1).i == 1+0xe0);
    assert(gtt!S(S(1), 1).i == 2+0xe0);
version(gcc7) {}
else
{
    assert(ft!S(1).i == 1+0xf);        // GCC inconsistent
    assert(ftt!S(S(1), 1).i == 2+0xf); // GCC inconsistent
}
    assert(fk!0(1).i == 1+0xf);
    assert(fk1(1).i == 2+0xf);
version(gcc6)
{
    assert(fei!0() == E0.a); // GCC only
    assert(fe() == E0.a);    // GCC only
}

version (linux)
{
    auto ss = toString("test013".ptr);
    assert(ss.data()[0..ss.length()] == "test013");
}

}
