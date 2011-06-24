import std.stdio;

/*********************************************/

int foo(int x)
{
    return mixin("x + 1"w);
}

void test1()
{
    assert(foo(3) == 4);
}

/*********************************************/

void test2()
{
    int j;
    mixin("
        int x = 3;
        for (int i = 0; i < 10; i++)
            writeln(x + i, ++j);
    ");
    assert(j == 10);
}

/*********************************************/

mixin("int abc3 = 5;");

void test3()
{
    writeln(abc3);
    assert(abc3 == 5);
}

/*********************************************/

mixin("
void test4()
{
    writeln(\"test4\");
" ~ "}");

/*********************************************/

int x5;

scope class Foo5
{
    this ()
    {
        writeln ("Constructor");
        assert(x5 == 0);
        x5++;
    }
    ~this ()
    {
        writeln ("Destructor");
        assert(x5 == 2);
        x5++;
    }
}

void test5()
{
    {
        mixin ("scope Foo5 f = new Foo5;\n");
        writeln ("  Inside Scope");
        assert(x5 == 1);
        x5++;
    }
    assert(x5 == 3);
}

/*********************************************/

void test6()
{
    static const b = "printf(`hey\n`);";

    if (true)
        mixin(b);
}

/*********************************************/

template Foo7(alias f)
{
}

class Bar7
{
        mixin Foo7!( function {} );
}

void test7()
{
}

/*********************************************/

template TupleDecls(T, R ...) {
    T value;
    static if (R.length)
        mixin TupleDecls!(R) Inner;
}

struct TupleStruct(T ...) { mixin TupleDecls!(T); }

void test8() {
    alias TupleStruct!(char[], char[]) twoStrings;
}

/*********************************************/

template Magic()
{
    void* magic = null;
}

struct Item
{
    mixin Magic A;
}

struct Foo9(alias S)
{
}

void test9()
{
    Foo9!(Item.A) bar;
}

/*********************************************/

pragma(msg, "hello");
pragma(msg, ['h', 'e', 'l', 'l', 'o']);
pragma(msg, "");
pragma(msg, []);
pragma(msg, null);
mixin("string hello;");
mixin(['i', 'n', 't', ' ', 't', 'e', 's', 't', '1', '0', 'x', ';']);
mixin("");
mixin([]);
mixin(null);
void test10()
{
    pragma(msg, "hello");
    pragma(msg, ['h', 'e', 'l', 'l', 'o']);
    pragma(msg, "");
    pragma(msg, []);
    pragma(msg, null);
    mixin("string hello;");
    mixin(['i', 'n', 't', ' ', 'a', ';']);
    mixin("");
    mixin([]);
    mixin(null);
}

/*********************************************/
// 7560

class Base7560
{
    template getter(T)
    {
        void get(ref T[] i, uint n) {}
    }
    mixin getter!uint;
    mixin getter!char;
}

class Derived7560 : Base7560
{
    alias Base7560.get get;
    void get(ref char[] x) {}
}

/*********************************************/
// 6207

mixin template Inj6207(string x)
{
    enum Inj6207 = x;
}
void test6207a()
{
    auto a = Inj6207!("10");
    assert(a == 10);
}

// ----

mixin template expand6207(string code)
{
    static if (code.length >= 2 && code[0..2] == "$x")
    {
        enum expand6207 = `x` ~ code[2..$];
        pragma(msg, expand6207);
    }
    else
        enum expand6207 = code;
}

void test6207b()
{
    int x = 1;
    int y = expand6207!q{$x+2};
        // Rhs is implicitly converted to mixin(expand6207!(q{$x+2}))
    assert(y == 3);
}

// ----

mixin template map6207(string pred)
{
    enum map6207 = `map6207!((a){ return `~pred~`; })`;
}
template map6207(alias pred)
{
    auto map6207(E)(E[] r)
    {
        E[] result;
        foreach (e; r)
            result ~= pred(e);
        return result;
    }
}

void test6207c()
{
    int b = 10;
    auto r = map6207!q{ a * b }([1,2,3]);
    //   --> mixin(`map6207!((a){ return ` ~ q{ a * b } ~ `; })`)([1,2,3])
    //   --> map6207!((a){ return  a * b ; })([1,2,3]);
    assert(r == [10,20,30]);
}

/*********************************************/

void main()
{
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    test9();
    test10();
    test6207a();
    test6207b();
    test6207c();

    writeln("Success");
}
