=== ${RESULTS_DIR}/compilable/testheader2.di
// D import file generated from 'compilable/extra-files/header2.d'
class C
{
}
void foo(const C c, const(char)[] s, const int* q, const(int*) p);
void bar(in void* p);
void f(void function() f2);
class C2;
void foo2(const C2 c);
struct Foo3
{
	int k;
	@nogc @live @trusted @disable ~this();
	this(this);
}
class C3
{
	@property int get();
}
T foo3(T)()
{
}
struct S4A(T)
{
	T x;
	@safe ~this()
	{
	}
}
struct S4B(T) if (1)
{
	T x;
}
union U4A(T)
{
	T x;
}
union U4B(T) if (2 * 4 == 8)
{
	T x;
}
class C4A(T)
{
	T x;
}
class C4B(T) if (true)
{
	T x;
}
class C4C(T) if (!false) : C4A!int
{
	T x;
}
class C4D(T) if (!false) : C4B!long, C4C!(int[])
{
	T x;
}
interface I4(T) if ((int[1]).length == 1)
{
	T x;
}
template MyClass4(T) if (is(typeof(T.subtype)))
{
	alias HelperSymbol = T.subtype;
	class MyClass4
	{
	}
}
enum isInt(T) = is(T == int);
enum bool isString(T) = is(T == string);
static immutable typeName(T) = T.stringof;
int storageFor(T) = 0;
enum int templateVariableFoo(T) = T.stringof.length;
template templateVariableBar(T) if (is(T == int))
{
	enum int templateVariableBar = T.stringof.length;
}
extern typeof(3 / 2.0) flit;
void foo11217()(const int[] arr)
{
}
void foo11217()(immutable int[] arr)
{
}
void foo11217()(ref int[] arr)
{
}
void foo11217()(lazy int[] arr)
{
}
void foo11217()(auto ref int[] arr)
{
}
void foo11217()(scope int[] arr)
{
}
void foo11217()(in int[] arr)
{
}
void foo11217()(inout int[] arr)
{
}
void test13275();
align (1) struct S9766
{
	align {}
	align (true ? 2 : 3)
	{
		int var1;
		align int var2;
	}
}
align (2) struct S12200_1
{
	align {}
}
align (2) struct S12200_2
{
	align (1) {}
}
pure nothrow @trusted inout(T)[] overlap(T)(inout(T)[] r1, inout(T)[] r2)
{
	alias U = inout(T);
	static nothrow U* max(U* a, U* b)
	{
		return a > b ? a : b;
	}
	static nothrow U* min(U* a, U* b)
	{
		return a < b ? a : b;
	}
	auto b = max(r1.ptr, r2.ptr);
	auto e = min(r1.ptr + r1.length, r2.ptr + r2.length);
	return b < e ? b[0..e - b] : null;
}
void gun()()
{
	int[] res;
	while (auto va = fun())
	{
	}
	while (true)
	if (auto va = fun())
	{
	}
	else
		break;
}
pragma (inline, true)int fun(int a, int b)
{
	return 3;
}
void leFoo()()
{
	sign = a == 2 ? false : (y < 0) ^ sign;
	sign = a == 2 ? false : sign ^ (y < 0);
	sign = 2 + 3 | 7 + 5;
}
interface LeInterface
{
}
class LeClass
{
	this();
}
extern const typeof(new class LeClass, LeInterface
{
}
) levar;
class CC
{
	@safe void fun()()
	{
		() pure @trusted
		{
		}
		();
	}
}
private struct Export
{
}