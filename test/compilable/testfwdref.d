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
// 9514

template TStructHelpers9514a()
{
    void opEquals(Foo9514a)
    {
        auto n = FieldNames9514a!();
    }
}

struct Foo9514a
{
    mixin TStructHelpers9514a!();
}

import imports.fwdref9514 : find9514;  // selective import without aliasing

template FieldNames9514a()
{
    static if (find9514!`true`([1])) enum int FieldNames9514a = 1;
}

// ----

template TStructHelpers9514b()
{
    void opEquals(Foo9514b)
    {
        auto n = FieldNames9514b!();
    }
}

struct Foo9514b
{
    mixin TStructHelpers9514b!();
}

import imports.fwdref9514 : foo9514 = find9514;  // selective import with aliasing

template FieldNames9514b()
{
    static if (foo9514!`true`([1])) enum int FieldNames9514b = 1;
}

/***************************************************/
// 10015

struct S10015(T) { alias X = int; }

alias Y10015 = s10015.X;
S10015!int s10015;

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
