// PERMUTE_ARGS:

/***************************************************/
// 6766

class Foo6766
{
    this(int x) { }
    void test(Foo6766 foo = new Foo6766(1)) { }
}

struct Bar6766
{
    this(int x) { }
    void test(Bar6766 bar = Bar6766(1)) { }
}

/***************************************************/
// 8609

struct Tuple8609(T)
{
    T arg;
}

// ----

struct Foo8609a
{
    Bar8609a b;
}
struct Bar8609a
{
    int x;
    Tuple8609!(Foo8609a) spam() { return Tuple8609!(Foo8609a)(); }
}

// ----

struct Foo8609b
{
    Bar8609b b;
}
struct Bar8609b
{
    int x;
    Tuple8609!(Foo8609b[1]) spam() { return Tuple8609!(Foo8609b[1])(); }
}

/***************************************************/
// 8698

interface IRoot8698a {}
interface IClass8698a : IRoot8698a { }
struct Struct8698a { }
class Class8698a : IClass8698a { alias Struct8698a Value; }
void test8698a(Class8698a.Value) { }
//interface IRoot8698a {}

// ----

//interface IRoot8698b {}
interface IClass8698b : IRoot8698b { }
struct Struct8698b { }
class Class8698b : IClass8698b { alias Struct8698b Value; }
void test8698b(Class8698b.Value) { }
interface IRoot8698b {}

/***************************************************/
// 12152

class A12152
{
    alias Y = B12152.X;
}

class B12152 : A12152
{
    alias int X;
}

static assert(is(A12152.Y == int));
