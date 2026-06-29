/*
REQUIRED_ARGS: -vcg-ast -o-
OUTPUT_FILES: compilable/vcg-ast-lowering.d.cg
TEST_OUTPUT:
---
=== compilable/vcg-ast-lowering.d.cg
module test;
import object;
class C : Object
{
}
T fun(T)(int x)
{
	return 2 * cast(T)x;
}
auto pure nothrow @safe void test()
{
	long x = fun!long(3);
	int[] a = null;
	short[] b = null;
	assert(!__equals!(int, short)(a[], b[]));
	Object o = _d_newclassT!(C)();
	C c = _d_cast!(C, Object)(o);
}
RTInfo!(C)
{
	enum immutable(void)* RTInfo = null;

}
fun!long
{
	pure nothrow @nogc @safe long fun(int x)
	{
		return 2L * cast(long)x;
	}

}
__equals!(int, short)
{
	pure nothrow @nogc @trusted bool __equals(scope int[] lhs, scope short[] rhs)
	{
		if (lhs.length != rhs.length)
			return false;
		if (lhs.length == 0LU)
			return true;
		alias PureType = bool function(scope int[], scope short[], ulong) pure nothrow @nogc @safe;
		return (*& isEqual)(lhs, rhs, lhs.length);
	}

}
isEqual!(int, short)
{
	pure nothrow @nogc @safe bool isEqual(scope int[] lhs, scope short[] rhs, ulong length)
	{
		static ref @trusted at(T)(scope T[] r, size_t i) if (!(is(T == struct) && !is(typeof(T.sizeof))))
		{
			static if (is(T == void))
			{
				return (cast(ubyte[])r)[i];
			}
			else
			{
				return r[i];
			}
		}
		{
			ulong __key3 = 0LU;
			ulong __limit4 = length;
			for (; __key3 < __limit4; __key3 += 1LU)
			{
				const const(ulong) i = __key3;
				if (at!int(lhs, i) != cast(int)at!short(rhs, i))
					return false;
			}
		}
		return true;
	}

}
at!int
{
	static pure nothrow @nogc ref @trusted int at(scope int[] r, ulong i)
	{
		return r[i];
	}

}
at!short
{
	static pure nothrow @nogc ref @trusted short at(scope short[] r, ulong i)
	{
		return r[i];
	}

}
_d_newclassT!(C)
{
	pure nothrow @trusted C _d_newclassT()
	{
		import core.internal.traits : hasIndirections;
		import core.exception : onOutOfMemoryError;
		import core.memory : pureMalloc;
		import core.memory : GC;
		alias BlkAttr = BlkAttr;
		const const(void[]) init = C;
		void* p = null;
		BlkAttr attr = BlkAttr.NONE;
		p = malloc(init.length, attr, typeid(C));
		p[0..init.length] = init[];
		return cast(C)p;
	}

}
hasIndirections!(C)
{
	enum bool hasIndirections = true;

}
_d_cast!(C, Object)
{
	pure nothrow @nogc @trusted void* _d_cast(Object o)
	{
		return _d_class_cast!(C)(o);
	}

}
_d_class_cast!(C)
{
	pure nothrow @nogc @safe void* _d_class_cast(return scope const(Object) o)
	{
		return _d_class_cast_impl(o, typeid(C));
	}

}
---
*/
// https://github.com/dlang/dmd/issues/23335

module test;

class C {}

T fun(T)(int x) { return 2*cast(T)x; }

auto test()
{
    auto x = fun!long(3);
    int[] a;
    short[] b;
    assert(a[] != b[]);
    Object o = new C;
    auto c = cast(C)o;
}
