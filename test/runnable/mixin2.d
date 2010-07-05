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

    writeln("Success");
}
