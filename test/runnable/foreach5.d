
import std.stdio;

/***************************************/

char[] a;

int foo()
{
    writefln("foo");
    a ~= "foo";
    return 10;
}

void test1()
{
    foreach (i; 0 .. foo())
    {
	writeln(i);
	a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789");

    foreach_reverse (i; 0 .. foo())
    {
	writeln(i);
	a ~= cast(char)('0' + i);
    }
    assert(a == "foo0123456789foo9876543210");
}

/***************************************/

int main()
{
    test1();

    writefln("Success");
    return 0;
}
