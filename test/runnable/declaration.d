
extern(C) int printf(const char*, ...);

/***************************************************/
// 481

enum size_t n481 = 3;
enum int[3] sa481 = [1,2];

struct S481a { int a; }
struct S481b { this(int n) {} }

int [3] a481_1x = [1,2,3];
auto[3] a481_1y = [1,2,3];
static assert(is(typeof(a481_1x) == typeof(a481_1y)));

int [n481] a481_2x = [1,2,3];
auto[n481] a481_2y = [1,2,3];
static assert(is(typeof(a481_2x) == typeof(a481_2y)));

int [3] a481_3x = [1,2,3];
auto[$] a481_3y = [1,2,3];
static assert(is(typeof(a481_3x) == typeof(a481_3y)));

int[2][3] a481_4x = [[1,2],[3,4],[5,6]];
int[2][$] a481_4y = [[1,2],[3,4],[5,6]];
static assert(is(typeof(a481_4x) == typeof(a481_4y)));

int[2][3] a481_5x = [[1,2],[3,4],[5,6]];
int[$][3] a481_5y = [[1,2],[3,4],[5,6]];
static assert(is(typeof(a481_5x) == typeof(a481_5y)));

int [2][3] a481_6x = [[1,2],[3,4],[5,6]];
auto[$][$] a481_6y = [[1,2],[3,4],[5,6]];
static assert(is(typeof(a481_6x) == typeof(a481_6y)));

int [2][2] a481_7x = [sa481[0..2], sa481[1..3]];
auto[$][$] a481_7y = [sa481[0..2], sa481[1..3]];
static assert(is(typeof(a481_7x) == typeof(a481_7y)));

S481a[2] a481_8x = [{a:1}, {a:2}];
S481a[$] a481_8y = [{a:1}, {a:2}];
static assert(is(typeof(a481_8x) == typeof(a481_8y)));

S481a[][1] a481_9x = [[{a:1}, {a:2}]];
S481a[][$] a481_9y = [[{a:1}, {a:2}]];
static assert(is(typeof(a481_9x) == typeof(a481_9y)));

S481a[2][] a481_10x = [[{a:1}, {a:2}]];
S481a[$][] a481_10y = [[{a:1}, {a:2}]];
static assert(is(typeof(a481_10x) == typeof(a481_10y)));

S481b[3] a481_11x = [1,2,3];  // [S481b(1), S481b(2), S481b(3)]
S481b[$] a481_11y = [1,2,3];  // dotto
static assert(is(typeof(a481_11x) == typeof(a481_11y)));

int [] a481_12x = sa481;
auto[] a481_12y = sa481;
static assert(is(typeof(a481_12x) == typeof(a481_12y)));

const(int[3]) a481_13x = [1,2,3];
const[$]      a481_13y = [1,2,3];
static assert(is(typeof(a481_13x) == typeof(a481_13y)));

const(int)[][3] a481_14x = [[1],[2],[3]];
const[][$]      a481_14y = [[1],[2],[3]];
static assert(is(typeof(a481_14x) == typeof(a481_14y)));

const(int)[] a481_15x = [1,2,3];
const[]      a481_15y = [1,2,3];
static assert(is(typeof(a481_15x) == typeof(a481_15y)));

const(int)[][] a481_16x = [[1,2,3]];
const[][]      a481_16y = [[1,2,3]];
static assert(is(typeof(a481_16x) == typeof(a481_16y)));

immutable(char)[3] a481_17x = "abc";
auto[$]            a481_17y = "abc";
static assert(is(typeof(a481_17x) == typeof(a481_17y)));

char[3] a481_18x = "abc";
char[$] a481_18y = "abc";
static assert(is(typeof(a481_18x) == typeof(a481_18y)));

void test481()
{
    assert(a481_1x == a481_1y);
    assert(a481_2x == a481_2y);
    assert(a481_3x == a481_3y);
    assert(a481_4x == a481_4y);
    assert(a481_5x == a481_5y);
    assert(a481_6x == a481_6y);
    assert(a481_7x == a481_7y);
    assert(a481_8x == a481_8y);
    assert(a481_9x == a481_9y);
    assert(a481_10x == a481_10y);
    assert(a481_11x == a481_11y);
    assert(a481_12x == a481_12y);
    assert(a481_13x == a481_13y);
    assert(a481_14x == a481_14y);
    assert(a481_15x == a481_15y);
    assert(a481_16x == a481_16y);

    int [3] a1x = [1,2,3];
    auto[3] a1y = [1,2,3];
    static assert(is(typeof(a1x) == typeof(a1y)));

    int [n481] a2x = [1,2,3];
    auto[n481] a2y = [1,2,3];
    static assert(is(typeof(a2x) == typeof(a2y)));

    int [3] a3x = [1,2,3];
    auto[$] a3y = [1,2,3];
    static assert(is(typeof(a3x) == typeof(a3y)));

    int[2][3] a4x = [[1,2],[3,4],[5,6]];
    int[2][$] a4y = [[1,2],[3,4],[5,6]];
    static assert(is(typeof(a4x) == typeof(a4y)));

    int[2][3] a5x = [[1,2],[3,4],[5,6]];
    int[$][3] a5y = [[1,2],[3,4],[5,6]];
    static assert(is(typeof(a5x) == typeof(a5y)));

    int [2][3] a6x = [[1,2],[3,4],[5,6]];
    auto[$][$] a6y = [[1,2],[3,4],[5,6]];
    static assert(is(typeof(a6x) == typeof(a6y)));

    int [2][2] a7x = [sa481[0..2], sa481[1..3]];
    auto[$][$] a7y = [sa481[0..2], sa481[1..3]];
    static assert(is(typeof(a7x) == typeof(a7y)));

    S481a[2] a8x = [{a:1}, {a:2}];
    S481a[$] a8y = [{a:1}, {a:2}];
    static assert(is(typeof(a8x) == typeof(a8y)));

    S481a[][1] a9x = [[{a:1}, {a:2}]];
    S481a[][$] a9y = [[{a:1}, {a:2}]];
    static assert(is(typeof(a9x) == typeof(a9y)));

    S481a[2][] a10x = [[{a:1}, {a:2}]];
    S481a[$][] a10y = [[{a:1}, {a:2}]];
    static assert(is(typeof(a10x) == typeof(a10y)));

  //S481b[3] a11x = [1,2,3];  // [S481b(1), S481b(2), S481b(3)]
    S481b[$] a11y = [1,2,3];  // dotto
    //static assert(is(typeof(a11x) == typeof(a11y)));
    static assert(is(typeof(a11y) == S481b[3]));

    int [] a12x = sa481;
    auto[] a12y = sa481;
    static assert(is(typeof(a12x) == typeof(a12y)));

    const(int[3]) a13x = [1,2,3];
    const[$]      a13y = [1,2,3];
    static assert(is(typeof(a13x) == typeof(a13y)));

    const(int)[][3] a14x = [[1],[2],[3]];
    const[][$]      a14y = [[1],[2],[3]];
    static assert(is(typeof(a14x) == typeof(a14y)));

    const(int)[] a15x = [1,2,3];
    const[]      a15y = [1,2,3];
    static assert(is(typeof(a15x) == typeof(a15y)));

    const(int)[][] a16x = [[1,2,3]];
    const[][]      a16y = [[1,2,3]];
    static assert(is(typeof(a16x) == typeof(a16y)));

    int num;
    int* p = &num;
    int** pp1 = &p;
    auto* pp2 = &p;
    static assert(is(typeof(pp1) == typeof(pp2)));

    const(int)* p1x = new int(3);
    const*      p1y = new int(3);
    static assert(is(typeof(p1x) == typeof(p1y)));

    const(int)*[] a17x = [new int(3)];
    const*[]      a17y = [new int(3)];
    static assert(is(typeof(a17x) == typeof(a17y)));

    enum E { a };
    E[$] esa0 = [];
    static assert(is(typeof(esa0) == E[0]));

    assert(a1x == a1y);
    assert(a2x == a2y);
    assert(a3x == a3y);
    assert(a4x == a4y);
    assert(a5x == a5y);
    assert(a6x == a6y);
    assert(a7x == a7y);
    assert(a8x == a8y);
    assert(a9x == a9y);
    assert(a10x == a10y);
    assert(a11y == [S481b(1), S481b(2), S481b(3)]);//assert(a11x == a11y);
    assert(a12x == a12y);
    assert(a13x == a13y);
    assert(a14x == a14y);
    assert(a15x == a15y);
    assert(a16x == a16y);
}

void test481b()
{
    auto[        auto] aa1 = [1:1, 2:2];
    auto[       const] aa2 = [1:1, 2:2];
    auto[   immutable] aa3 = [1:1, 2:2];
    auto[shared const] aa4 = [1:1, 2:2];
    static assert(is(typeof(aa1) == int[             int]));
    static assert(is(typeof(aa2) == int[       const int]));
    static assert(is(typeof(aa3) == int[   immutable int]));
    static assert(is(typeof(aa4) == int[shared const int]));

    auto[        auto[$]] aa5 = [[1,2]:1, [3,4]:2];
    auto[       const[$]] aa6 = [[1,2]:1, [3,4]:2];
    auto[   immutable[$]] aa7 = [[1,2]:1, [3,4]:2];
    auto[shared const[$]] aa8 = [[1,2]:1, [3,4]:2];
    static assert(is(typeof(aa5) == int[             int[2]]));
    static assert(is(typeof(aa6) == int[       const int[2]]));
    static assert(is(typeof(aa7) == int[   immutable int[2]]));
    static assert(is(typeof(aa8) == int[shared const int[2]]));

    auto[        auto[]] aa9  = [[1,2]:1, [3,4]:2];
    auto[       const[]] aa10 = [[1,2]:1, [3,4]:2];
    auto[   immutable[]] aa11 = [[1,2]:1, [3,4]:2];
    auto[shared const[]] aa12 = [[1,2]:1, [3,4]:2];
    static assert(is(typeof(aa9 ) == int[             int []]));
    static assert(is(typeof(aa10) == int[       const(int)[]]));
    static assert(is(typeof(aa11) == int[   immutable(int)[]]));
    static assert(is(typeof(aa12) == int[shared(const int)[]]));

    short[auto[$][$]] aa13 = [[[1],[2]]:1, [[3],[4]]:2];
    static assert(is(typeof(aa13) == short[int[1][2]]));

    auto[long[$][$]] aa14 = [[[1],[2]]:1, [[3],[4]]:2];
    static assert(is(typeof(aa14) == int[long[1][2]]));

    int[int[][$]] aa15 = [[[1],[2]]:1, [[3],[4]]:2];
    static assert(is(typeof(aa15) == int[int[][2]]));
}

/***************************************************/
// 6475

class Foo6475(Value)
{
    template T1(size_t n){ alias int T1; }
}

void test6475()
{
    alias Foo6475!(int) C1;
    alias C1.T1!0 X1;
    static assert(is(X1 == int));

    alias const(Foo6475!(int)) C2;
    alias C2.T1!0 X2;
    static assert(is(X2 == int));
}

/***************************************************/
// 6905

void test6905()
{
    auto foo1() { static int n; return n; }
    auto foo2() {        int n; return n; }
    auto foo3() {               return 1; }
    static assert(typeof(&foo1).stringof == "int delegate()");
    static assert(typeof(&foo2).stringof == "int delegate()");
    static assert(typeof(&foo3).stringof == "int delegate()");

    ref bar1() { static int n; return n; }
  static assert(!__traits(compiles, {
    ref bar2() {        int n; return n; }
  }));
  static assert(!__traits(compiles, {
    ref bar3() {               return 1; }
  }));

    auto ref baz1() { static int n; return n; }
    auto ref baz2() {        int n; return n; }
    auto ref baz3() {               return 1; }
    static assert(typeof(&baz1).stringof == "int delegate() ref");
    static assert(typeof(&baz2).stringof == "int delegate()");
    static assert(typeof(&baz3).stringof == "int delegate()");
}

/***************************************************/
// 7019

struct S7019
{
    int store;
    this(int n)
    {
        store = n << 3;
    }
}

S7019 rt_gs = 2;
enum S7019 ct_gs = 2;
pragma(msg, ct_gs, ", ", ct_gs.store);

void test7019()
{
    S7019 rt_ls = 3; // this compiles fine
    enum S7019 ct_ls = 3;
    pragma(msg, ct_ls, ", ", ct_ls.store);

    static class C
    {
        S7019 rt_fs = 4;
        enum S7019 ct_fs = 4;
        pragma(msg, ct_fs, ", ", ct_fs.store);
    }

    auto c = new C;
    assert(rt_gs == S7019(2) && rt_gs.store == 16);
    assert(rt_ls == S7019(3) && rt_ls.store == 24);
    assert(c.rt_fs == S7019(4) && c.rt_fs.store == 32);
    static assert(ct_gs == S7019(2) && ct_gs.store == 16);
    static assert(ct_ls == S7019(3) && ct_ls.store == 24);
    static assert(C.ct_fs == S7019(4) && C.ct_fs.store == 32);

    void foo(S7019 s = 5)   // fixing bug 7152
    {
        assert(s.store == 5 << 3);
    }
    foo();
}

/***************************************************/
// 7239

struct vec7239
{
    float x, y, z, w;
    alias x r;  //! for color access
    alias y g;  //! ditto
    alias z b;  //! ditto
    alias w a;  //! ditto
}

void test7239()
{
    vec7239 a = {x: 0, g: 0, b: 0, a: 1};
    assert(a.r == 0);
    assert(a.g == 0);
    assert(a.b == 0);
    assert(a.a == 1);
}

/***************************************************/
struct S10635
{
    string str;

    this(string[] v) { str = v[0]; }
    this(string[string] v) { str = v.keys[0]; }
}

S10635 s10635a = ["getnonce"];
S10635 s10635b = ["getnonce" : "str"];

void test10635()
{
    S10635 sa = ["getnonce"];
    S10635 sb = ["getnonce" : "str"];
}

/***************************************************/
// 8123

void test8123()
{
    struct S { }

    struct AS
    {
        alias S Alias;
    }

    struct Wrapper
    {
        AS as;
    }

    Wrapper w;
    static assert(is(typeof(w.as).Alias == S));         // fail
    static assert(is(AS.Alias == S));                   // ok
    static assert(is(typeof(w.as) == AS));              // ok
    static assert(is(typeof(w.as).Alias == AS.Alias));  // fail
}

/***************************************************/
// 8147

enum A8147 { a, b, c }

@property ref T front8147(T)(T[] a)
if (!is(T[] == void[]))
{
    return a[0];
}

template ElementType8147(R)
{
    static if (is(typeof({ R r = void; return r.front8147; }()) T))
        alias T ElementType8147;
    else
        alias void ElementType8147;
}

void test8147()
{
    auto arr = [A8147.a];
    alias typeof(arr) R;
    auto e = ElementType8147!R.init;
}

/***************************************************/
// 8410

void test8410()
{
    struct Foo { int[15] x; string s; }

    Foo[5] a1 = Foo([0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], "hello"); // OK
    Foo f = { s: "hello" }; // OK (not static)
    Foo[5] a2 = { s: "hello" }; // error
}

/***************************************************/
// 8942

alias const int A8942_0;
static assert(is(A8942_0 == const int)); // passes

void test8942()
{
    alias const int A8942_1;
    static assert(is(A8942_1 == const int)); // passes

    static struct S { int i; }
    foreach (Unused; typeof(S.tupleof))
    {
        alias const(int) A8942_2;
        static assert(is(A8942_2 == const int)); // also passes

        alias const int A8942_3;
        static assert(is(A8942_3 == const int)); // fails
        // Error: static assert  (is(int == const(int))) is false
    }
}

/***************************************************/
// 10144

final class TNFA10144(char_t)
{
    enum Act { don }
    const Act[] action_lookup1 = [ Act.don, ];
}
alias X10144 = TNFA10144!char;

class C10144
{
    enum Act { don }
    synchronized { enum x1 = [Act.don]; }
    override     { enum x2 = [Act.don]; }
    abstract     { enum x3 = [Act.don]; }
    final        { enum x4 = [Act.don]; }
    synchronized { static s1 = [Act.don]; }
    override     { static s2 = [Act.don]; }
    abstract     { static s3 = [Act.don]; }
    final        { static s4 = [Act.don]; }
    synchronized { __gshared gs1 = [Act.don]; }
    override     { __gshared gs2 = [Act.don]; }
    abstract     { __gshared gs3 = [Act.don]; }
    final        { __gshared gs4 = [Act.don]; }
}

/***************************************************/

// 10142

class File10142
{
    enum Access : ubyte { Read = 0x01 }
    enum Open : ubyte { Exists = 0 }
    enum Share : ubyte { None = 0 }
    enum Cache : ubyte { None = 0x00 }

    struct Style
    {
        Access  access;
        Open    open;
        Share   share;
        Cache   cache;
    }
    enum Style ReadExisting = { Access.Read, Open.Exists };

    this (const(char[]) path, Style style = ReadExisting)
    {
        assert(style.access == Access.Read);
        assert(style.open   == Open  .Exists);
        assert(style.share  == Share .None);
        assert(style.cache  == Cache .None);
    }
}

void test10142()
{
    auto f = new File10142("dummy");
}

/***************************************************/
// 11421

void test11421()
{
    // AAs in array
    const            a1 = [[1:2], [3:4]];   // ok <- error
    const int[int][] a2 = [[1:2], [3:4]];   // ok
    static assert(is(typeof(a1) == typeof(a2)));

    // AAs in AA
    auto aa = [1:["a":1.0], 2:["b":2.0]];
    static assert(is(typeof(aa) == double[string][int]));
    assert(aa[1]["a"] == 1.0);
    assert(aa[2]["b"] == 2.0);
}

/***************************************************/
// 13776

enum a13776(T) = __traits(compiles, { T; });

enum b13776(A...) = 1;

template x13776s()
{
    struct S;
    alias x13776s = b13776!(a13776!S);
}
template y13776s()
{
    struct S;
    alias x2 = b13776!(a13776!S);
    alias y13776s = x2;
}
template z13776s()
{
    struct S;
    alias x1 = a13776!S;
    alias x2 = b13776!(x1);
    alias z13776s = x2;
}

template x13776c()
{
    class C;
    alias x13776c = b13776!(a13776!C);
}
template y13776c()
{
    class C;
    alias x2 = b13776!(a13776!C);
    alias y13776c = x2;
}
template z13776c()
{
    class C;
    alias x1 = a13776!C;
    alias x2 = b13776!(x1);
    alias z13776c = x2;
}

void test13776()
{
    alias xs = x13776s!();  // ok <- ng
    alias ys = y13776s!();  // ok <- ng
    alias zs = z13776s!();  // ok

    alias xc = x13776c!();  // ok <- ng
    alias yc = y13776c!();  // ok <- ng
    alias zc = z13776c!();  // ok
}

/***************************************************/
// 13950

template Tuple13950(T...) { alias T Tuple13950; }

void f13950(int x = 0, Tuple13950!() xs = Tuple13950!())
{
    assert(x == 0);
    assert(xs.length == 0);
}

void test13950()
{
    f13950();
}

/***************************************************/

int main()
{
    test481();
    test6475();
    test6905();
    test7019();
    test7239();
    test8123();
    test8147();
    test8410();
    test8942();
    test10142();
    test11421();
    test13950();

    printf("Success\n");
    return 0;
}
