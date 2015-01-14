// REQUIRED_ARGS: -dip25

import core.stdc.stdio;

/********************************************/

struct SS
{
    ref int foo1(return ref int delegate() return p) return;
    ref int foo2(return ref int delegate() p);
    ref int foo3(inout ref int* p);
    ref int foo4(return inout ref int* p);
}

pragma(msg, "foo1 ", typeof(&SS.foo1));
pragma(msg, "foo2 ", typeof(&SS.foo2));
pragma(msg, "foo3 ", typeof(&SS.foo3));
pragma(msg, "foo4 ", typeof(&SS.foo4));


void test3()
{
    version (all)
    {
	import std.stdio;
	writeln(SS.foo1.mangleof);
	writeln(SS.foo2.mangleof);
	writeln(SS.foo3.mangleof);
	writeln(SS.foo4.mangleof);
	writeln(typeof(SS.foo1).stringof);
	writeln(typeof(SS.foo2).stringof);
	writeln(typeof(SS.foo3).stringof);
	writeln(typeof(SS.foo4).stringof);
    }

    version (all)
    {
	// Test scope mangling
	assert(SS.foo1.mangleof == "_D10testscope22SS4foo1MFNcNjNkKDFNjZiZi");
	assert(SS.foo2.mangleof == "_D10testscope22SS4foo2MFNcNkKDFZiZi");
	assert(SS.foo3.mangleof == "_D10testscope22SS4foo3MFNcNkKNgPiZi");
	assert(SS.foo4.mangleof == "_D10testscope22SS4foo4MFNcNkKNgPiZi");

	// Test scope pretty-printing
	assert(typeof(SS.foo1).stringof == "ref int(return ref int delegate() return p)return ");
	assert(typeof(SS.foo2).stringof == "ref int(return ref int delegate() p)");
	assert(typeof(SS.foo3).stringof == "ref int(return ref inout(int*) p)");
	assert(typeof(SS.foo4).stringof == "ref int(return ref inout(int*) p)");
    }
}

/********************************************/

ref int foo(return ref int x)
{
    return x;
}

struct S
{
    int x;

    ref S bar() return
    {
	return this;
    }
}

ref T foo2(T)(ref T x)
{
    return x;
}

void test4()
{
    int x;
    foo2(x);
}

/********************************************/

void main()
{
    test3();
    test4();
    printf("Success\n");
}

