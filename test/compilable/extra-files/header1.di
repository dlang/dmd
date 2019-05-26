module foo.bar;
import core.vararg;
import std.stdio;
pragma (lib, "test");
pragma (msg, "Hello World");
pragma (linkerDirective, "/DEFAULTLIB:test2");
static assert(true, "message");
alias mydbl = double;
alias fl1 = function ()
in
{
}
in (true)
out (; true)
out (r; true)
out
{
}
out(r)
{
}
do
{
	return 2;
}
;
alias fl2 = function ()
in (true)
out (; true)
out (r; true)
{
	return 2;
}
;
int testmain();
struct S
{
	int m;
	int n;
}
template Foo(T, int V)
{
	void foo(...)
	{
		static if (is(Object _ : X!TL, alias X, TL...))
		{
		}

		auto x = __traits(hasMember, Object, "noMember");
		auto y = is(Object : X!TL, alias X, TL...);
		assert(!x && !y, "message");
		S s = {1, 2};
		auto a = [1, 2, 3];
		auto aa = [1:1, 2:2, 3:3];
		int n, m;
	}
	int bar(double d, int x)
	{
		if (d)
		{
			d++;
		}
		else
			d--;
		asm { naked; }
		asm { mov EAX,3; }
		for (;;)
		{
			{
				d = d + 1;
			}
		}
		for (int i = 0;
		 i < 10; i++)
		{
			{
				d = i ? d + 1 : 5;
			}
		}
		char[] s;
		foreach (char c; s)
		{
			d *= 2;
			if (d)
				break;
			else
				continue;
		}
		switch (V)
		{
			case 1:
			{
			}
			case 2:
			{
				break;
			}
			case 3:
			{
				goto case 1;
			}
			case 4:
			{
				goto default;
			}
			default:
			{
				d /= 8;
				break;
			}
		}
		enum Label 
		{
			A,
			B,
			C,
		}
		void fswitch(Label l);
		loop:
		while (x)
		{
			x--;
			if (x)
				break loop;
			else
				continue loop;
		}
		do
		{
			x++;
		}
		while (x < 10);
		try
		{
			try
			{
				bar(1, 2);
			}
			catch(Object o)
			{
				x++;
			}
		}
		finally
		{
			x--;
		}
		try
		{
			try
				bar(1, 2);
			catch(Object o)
			{
				x++;
			}
		}
		finally
			x--;
		Object o;
		synchronized(o) {
			x = ~x;
		}
		synchronized {
			x = x < 3;
		}
		with (o)
		{
			toString();
		}
	}
}
static this();
static ~this();
nothrow pure @nogc @safe static this();
nothrow pure @nogc @safe static ~this();
nothrow pure @nogc @safe static this();
nothrow pure @nogc @safe static ~this();
nothrow pure @nogc @safe shared static this();
nothrow pure @nogc @safe shared static ~this();
nothrow pure @nogc @safe shared static this();
nothrow pure @nogc @safe shared static ~this();
interface iFoo
{
}
class xFoo : iFoo
{
}
interface iFoo2
{
}
class xFoo2 : iFoo, iFoo2
{
}
class Foo3
{
	this(int a, ...)
	{
	}
	this(int* a)
	{
	}
}
alias myint = int;
static notquit = 1;
class Test
{
	void a();
	void b();
	void c();
	void d();
	void e();
	void f();
	void g();
	void h();
	void i();
	void j();
	void k();
	void l();
	void m();
	void n();
	void o();
	void p();
	void q();
	void r();
	void s();
	void t();
	void u();
	void v();
	void w();
	void x();
	void y();
	void z();
	void aa();
	void bb();
	void cc();
	void dd();
	void ee();
	template A(T)
	{
	}
	alias getHUint = A!uint;
	alias getHInt = A!int;
	alias getHFloat = A!float;
	alias getHUlong = A!ulong;
	alias getHLong = A!long;
	alias getHDouble = A!double;
	alias getHByte = A!byte;
	alias getHUbyte = A!ubyte;
	alias getHShort = A!short;
	alias getHUShort = A!ushort;
	alias getHReal = A!real;
	alias void F();
}
void templ(T)(T val)
{
	pragma (msg, "Invalid destination type.");
}
static char[] charArray = ['"', '\''];
class Point
{
	auto x = 10;
	uint y = 20;
}
template Foo2(bool bar)
{
	void test()
	{
		static if (bar)
		{
			int i;
		}
		else
		{
		}
		static if (!bar)
		{
		}
		else
		{
		}
	}
}
template Foo4()
{
	void bar()
	{
	}
}
template Foo4x(T...)
{
}
class Baz4
{
	mixin Foo4!() foo;
	mixin Foo4x!(int, "str") foox;
	alias baz = foo.bar;
}
int test(T)(T t)
{
	if (auto o = cast(Object)t)
		return 1;
	return 0;
}
enum x6 = 1;
bool foo6(int a, int b, int c, int d);
auto foo7(int x)
{
	return 5;
}
class D8
{
}
void func8();
T func9(T)() if (true)
{
	T i;
	scope(exit) i = 1;
	scope(success) i = 2;
	scope(failure) i = 3;
	return i;
}
template V10(T)
{
	void func()
	{
		for (int i, j = 4; i < 3; i++)
		{
			{
			}
		}
	}
}
int foo11(int function() fn);
int bar11(T)()
{
	return foo11(function int()
	{
		return 0;
	}
	);
}
struct S6360
{
	const pure nothrow @property long weeks1();
	const pure nothrow @property long weeks2();
}
struct S12
{
	nothrow this(int n)
	{
	}
	nothrow this(string s)
	{
	}
}
struct T12
{
	immutable this()(int args)
	{
	}
	immutable this(A...)(A args)
	{
	}
}
import std.stdio : writeln, F = File;
void foo6591()()
{
	import std.stdio : writeln, F = File;
}
version (unittest)
{
	public {}
	extern (C) {}
	align {}
}
template Foo10334(T) if (Bar10334!())
{
}
template Foo10334(T) if (Bar10334!100)
{
}
template Foo10334(T) if (Bar10334!3.14)
{
}
template Foo10334(T) if (Bar10334!"str")
{
}
template Foo10334(T) if (Bar10334!1.4i)
{
}
template Foo10334(T) if (Bar10334!null)
{
}
template Foo10334(T) if (Bar10334!true)
{
}
template Foo10334(T) if (Bar10334!false)
{
}
template Foo10334(T) if (Bar10334!'A')
{
}
template Foo10334(T) if (Bar10334!int)
{
}
template Foo10334(T) if (Bar10334!string)
{
}
template Foo10334(T) if (Bar10334!wstring)
{
}
template Foo10334(T) if (Bar10334!dstring)
{
}
template Foo10334(T) if (Bar10334!this)
{
}
template Foo10334(T) if (Bar10334!([1, 2, 3]))
{
}
template Foo10334(T) if (Bar10334!(Baz10334!()))
{
}
template Foo10334(T) if (Bar10334!(Baz10334!T))
{
}
template Foo10334(T) if (Bar10334!(Baz10334!100))
{
}
template Foo10334(T) if (Bar10334!(.foo))
{
}
template Foo10334(T) if (Bar10334!(const(int)))
{
}
template Foo10334(T) if (Bar10334!(shared(T)))
{
}
template Test10334(T...)
{
}
mixin Test10334!int a;
mixin Test10334!(int, long) b;
mixin Test10334!"str" c;
auto clamp12266a(T1, T2, T3)(T1 x, T2 min_val, T3 max_val)
{
	return 0;
}
pure clamp12266b(T1, T2, T3)(T1 x, T2 min_val, T3 max_val)
{
	return 0;
}
@disable pure clamp12266c(T1, T2, T3)(T1 x, T2 min_val, T3 max_val)
{
	return 0;
}
alias Dg13832 = ref int delegate();
class TestClass
{
	int aa;
	int b1;
	int b2;
	this(int b1, int b2)
	{
		this.b1 = b1;
		this.b2 = b2;
	}
	ref foo()
	{
		return aa;
	}
	ref retFunc() return
	{
		return aa;
	}
	@trusted @nogc @disable ~this();
}
class FooA
{
	protected void method42();
	@safe ~this();
}
class Bar : FooA
{
	override void method42();
}
@trusted double foo();
struct Foo1(size_t Size = 42 / magic())
{
}
size_t magic();
class Foo2A
{
	immutable(FooA) Dummy = new immutable(FooA);
	private immutable pure nothrow @nogc @safe this()
	{
	}
}
struct Foo3A(T)
{
	@disable this(this);
	@disable this();
}
ref @safe int foo(return ref int a);
@safe int* foo(return scope int* a);
ref @safe int* foo(return ref scope int* a);
struct SafeS
{
	@safe 
	{
		ref SafeS foo() return;
		scope SafeS foo2() return;
		ref scope SafeS foo3() return;
		int* p;
	}
}
void test13x(@(10) int a, @(20) int, @(tuple(30), tuple(40)) int[] arr...);
enum Test14UDA1 ;
struct Test14UDA2
{
	string str;
}
Test14UDA2 test14uda3(string name);
struct Test14UDA4(string v)
{
}
void test14x(@(Test14UDA1) int, @Test14UDA2("1") int, @test14uda3("2") int, @(Test14UDA4!"3") int);
void test15x(@(20) void delegate(int) @safe dg);
