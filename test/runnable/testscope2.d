// REQUIRED_ARGS: -scope

import core.stdc.stdio;

/********************************************/

struct S1
{
  scope:
  scope
    int* foo(scope int *p) scope
    {
	return p;
    }
}

/********************************************/

alias ref int delegate() dg_t;

pragma(msg, dg_t);

struct S
{
  scope int* foo1(scope int* delegate() scope p) scope;
  scope int* foo2(scope int* delegate() p);
        int* foo3(int* delegate() scope p) scope;
        int* foo4(int* delegate() p);

  ref   int* foo5(ref int *p);
}

pragma(msg, "foo1 ", typeof(&S.foo1));
pragma(msg, "foo2 ", typeof(&S.foo2));
pragma(msg, "foo3 ", typeof(&S.foo3));
pragma(msg, "foo4 ", typeof(&S.foo4));
pragma(msg, "foo5 ", typeof(&S.foo5));

import std.stdio;

void test2()
{
    version (none)
    {
	writeln(S.foo1.mangleof);
	writeln(S.foo2.mangleof);
	writeln(S.foo3.mangleof);
	writeln(S.foo4.mangleof);
	writeln(S.foo5.mangleof);
	writeln(typeof(S.foo1).stringof);
	writeln(typeof(S.foo2).stringof);
	writeln(typeof(S.foo3).stringof);
	writeln(typeof(S.foo4).stringof);
	writeln(typeof(S.foo5).stringof);
    }

    // Test scope mangling
    assert(S.foo1.mangleof == "_D10testscope21S4foo1MFNjNkDFNjNkZPiZPi");
    assert(S.foo2.mangleof == "_D10testscope21S4foo2MFNjDFNjZPiZPi");
    assert(S.foo3.mangleof == "_D10testscope21S4foo3MFNkDFNkZPiZPi");
    assert(S.foo4.mangleof == "_D10testscope21S4foo4MFDFZPiZPi");
    assert(S.foo5.mangleof == "_D10testscope21S4foo5MFNcKPiZPi");

    // Test scope pretty-printing
    assert(typeof(S.foo1).stringof == "scope int*(scope int* delegate() scope p)scope ");
    assert(typeof(S.foo2).stringof == "scope int*(scope int* delegate() p)");
    assert(typeof(S.foo3).stringof == "int*(int* delegate() scope p)scope ");
    assert(typeof(S.foo4).stringof == "int*(int* delegate() p)");
    assert(typeof(S.foo5).stringof == "ref int*(ref int* p)");
}

/********************************************/

void main()
{
    test2();
    printf("Success\n");
}

