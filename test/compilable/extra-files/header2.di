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
	~this();
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
auto flit = 3 / 2.00000;
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
