module foo.bar;
import core.vararg;
import std.stdio;
pragma (lib, "test");
pragma (msg, "Hello World");
static assert(true, "message");
typedef double mydbl = 10;
int main();
struct S
{
	int m;
	int n;
}
template Foo(T, int V)
{
	void foo(...)
	{
		static if (is(Object _ : X!(TL), alias X, TL...))
		{
		}

		auto x = __traits(hasMember, Object, "noMember");
		auto y = is(Object : X!(TL), alias X, TL...);
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
		{
			for (int i = 0;
			 i < 10; i++)
			{
				{
					d = i ? d + 1 : 5;
				}
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
		;
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
	this(int a, ...);
	this(int* a);
}
alias int myint;
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
	alias A!(uint) getHUint;
	alias A!(int) getHInt;
	alias A!(float) getHFloat;
	alias A!(ulong) getHUlong;
	alias A!(long) getHLong;
	alias A!(double) getHDouble;
	alias A!(byte) getHByte;
	alias A!(ubyte) getHUbyte;
	alias A!(short) getHShort;
	alias A!(ushort) getHUShort;
	alias A!(real) getHReal;
}
template templ(T)
{
	void templ(T val)
	{
		pragma (msg, "Invalid destination type.");
	}

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
	alias foo.bar baz;
}
template test(T)
{
	int test(T t)
	{
		if (auto o = cast(Object)t)
			return 1;
		return 0;
	}

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
template func9(T)
{
	T func9()
	{
		T i;
		scope(exit) i = 1;
		scope(success) i = 2;
		scope(failure) i = 3;
		return i;
	}

}
template V10(T)
{
	void func()
	{
		{
			for (int i, j = 4; i < 3; i++)
			{
				{
				}
			}
		}
	}

}
int foo11(int function() fn);
template bar11(T)
{
	int bar11()
	{
		return foo11(function int()
		{
			return 0;
		}
		);
	}

}
struct S6360
{
	@property const pure nothrow long weeks1();

	const nothrow pure @property long weeks2();

}
struct S12
{
	nothrow this(int n);
	nothrow this(string s);

}
struct T12
{
	template __ctor()
	{
		immutable this(int args)
		{
		}

	}
	immutable template __ctor(A...)
	{
		this(A args)
		{
		}

	}

}
import std.stdio : writeln, F = File;
template foo6591()
{
	void foo6591()
	{
		import std.stdio : writeln, F = File;
	}

}
version (unittest)
{
	nothrow pure {}
	nothrow pure {}
	public {}
	extern (C) {}
	align{}
}
