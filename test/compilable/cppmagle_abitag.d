// DISABLED: win32 win64

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
    this(int);
}

@foo_bar
extern __gshared int a;
static assert(a.mangleof == "_Z1aB3barB3foo");

extern __gshared S b;
static assert(b.mangleof == "_Z1bB3barB3foo");

@foo_bar
int f();
static assert(f.mangleof == "_Z1fB3barB3foov");

S gs(int);
S gss(S, int);
static assert(gs.mangleof == "_Z2gsB3barB3fooi");
static assert(gss.mangleof == "_Z3gss1SB3barB3fooi");

@foo_bar
S fss(S, int);
static assert(gs.mangleof == "_Z2gsB3barB3fooi");

T gt(T)(int);
T gtt(T)(T, int);
static assert(gt!S.mangleof == "_Z2gtI1SB3barB3fooET_i");
static assert(gtt!S.mangleof == "_Z3gttI1SB3barB3fooET_S1_i");

@foo_bar
T ft(T)(int);
// matches Clang and GCC <= 6
static assert(ft!S.mangleof == "_Z2ftB3barB3fooI1SB3barB3fooET_i");

@foo_bar
T ftt(T)(T, int);
// matches Clang and GCC <= 6
static assert(ftt!S.mangleof == "_Z3fttB3barB3fooI1SB3barB3fooET_S1_i");

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

// make sure `gnuAbiTag("AAA")` is not inherited from namespace
static assert(__traits(getAttributes, K!0) == Tuple!("abc", gnuAbiTag("foo"), gnuAbiTag("bar")));

K!i fk(int i)(int);
K!1 fk1(int);
static assert(fk!0.mangleof == "_Z2fkILi0EEN1N1KB3barB3fooIXT_EEEi");
static assert(fk1.mangleof == "_Z3fk1B3AAAB3barB3fooi");

extern __gshared K!10 k10;
static assert(k10.mangleof == "_Z3k10B3AAAB3barB3foo");

// GCC >= 6 only
@gnuAbiTag("ENN")
enum E0 { a = 0xa, }
E0 fe();
E0 fei(int i)();
static assert(fe.mangleof == "_Z2feB3ENNv");
static assert(fei!0.mangleof == "_Z3feiILi0EE2E0B3ENNv");

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
static assert(toString.mangleof == "_Z8toStringB5cxx11PKc");

@gnuAbiTag("A", "B")
{
    void fun0();
    static assert(fun0.mangleof == "_Z4fun0B1AB1Bv");
}

@gnuAbiTag("C", "D"):

void fun1();
static assert(fun1.mangleof == "_Z4fun1B1CB1Dv");

void fun2();
static assert(fun2.mangleof == "_Z4fun2B1CB1Dv");
