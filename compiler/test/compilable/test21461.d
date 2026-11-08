// https://github.com/dlang/dmd/issues/21461
// https://github.com/dlang/dmd/issues/20387
// https://github.com/dlang/dmd/issues/18073
// Static arrays are value types, so assigning one in CTFE has to copy the
// payload. Previously only static arrays of structs were copied, so for any
// other element type both variables ended up sharing one array literal and
// mutating either was visible through the other.

// https://github.com/dlang/dmd/issues/21461
int[1] construct()
{
    int[1] s = [1];
    int[1] t = s;
    s[0] = 2;
    return t;
}
static assert(construct() == [1]);

// Plain assignment, not construction.
int[2] assign()
{
    int[2] s = [1, 1];
    int[2] t;
    t = s;
    s[0] = 9;
    return t;
}
static assert(assign() == [1, 1]);

// Nested static arrays copy at every level.
int[2][2] nested()
{
    int[2][2] s = [[1, 1], [1, 1]];
    int[2][2] t = s;
    s[0][0] = 9;
    return t;
}
static assert(nested() == [[1, 1], [1, 1]]);

// A static array parameter copied into a local.
int[2] fromParam(int[2] p)
{
    int[2] u = p;
    p[0] = 9;
    return u;
}
static assert(fromParam([1, 1]) == [1, 1]);

// Static array of structs: this already worked, keep it working.
struct S { int x; }
S[2] structElems()
{
    S[2] s = [S(1), S(1)];
    S[2] t = s;
    s[0].x = 9;
    return t;
}
static assert(structElems() == [S(1), S(1)]);

// A static char array initialised from a string literal is a StringExp
// rather than an ArrayLiteralExp, so it takes a different path.
char[4] fromString()
{
    char[4] a = "abcd";
    char[4] b = a;
    a[0] = 'z';
    return b;
}
static assert(fromString() == "abcd");

// https://github.com/dlang/dmd/issues/20387
ubyte[1] byRef()
{
    ubyte[1] arr = [0];
    auto copy = arr;
    copy[0] = 42;
    return arr;
}
static assert(byRef() == [0]);

// https://github.com/dlang/dmd/issues/18073
// Copying a const static array parameter used to be rejected outright.
int fromConstParam(const uint[2] arr)
{
    uint[2] copy = arr;
    copy[0] = 0;
    return copy[1];
}
static assert(fromConstParam([4, 8]) == 8);
