enum union Option(T)
{
	case Some(T),
	case None,
}

enum union Shape
{
	case Circle(double),
	case Rectangle(double, double),
	case Point,
}

void main()
{
	auto s1 = Shape.Circle(3.5);
	auto s2 = Shape.Point;
	assert(s1.__tag == 0);
	assert(s2.__tag == 2);

	int getScore(Shape s)
	{
		return switch (s)
		{
			case Circle(r) => cast(int)(r * 2),
			case Rectangle(w, h) => cast(int)(w * h),
			case Point => 1,
		};
	}
	assert(getScore(s1) == 7);
	assert(getScore(s2) == 1);
	assert(getScore(Shape.Rectangle(4.0, 5.0)) == 20);

	auto r1 = Shape.Rectangle(4.0, 5.0);
	assert(r1.__tag == 1);

	Option!string opt = Option!string.Some("hello");
	assert(opt.__tag == 0);
	Option!string empty = Option!string.None;
	assert(empty.__tag == 1);

	string text = switch (opt)
	{
	    case Some(msg) => msg ~ " world",
	    case None => "empty",
	};
	assert(text == "hello world");

	testImplicitConversion();
	testBareTypes();
	testNullLikeBareType();
	testStructVariant();
	testHybridResponse();
	testGuards();
	testCompoundTypes();
	testCallables();
	testBareCompoundTypes();
	testBareCallables();
	testMemberFunctions();
	testExhaustiveness();
	testLifecycleCopyableVariant();
}

// Regression test: implicit conversion of variant-construction expressions
// on `return` and when passing arguments to a function parameter.
enum union Account
{
	case User(int, string),
	case Admin(int, string),
}

Account getAccount()
{
	return Account.User(42, "alice"); // implicit conversion on return
}

int accessAccount(Account a) // implicit conversion on argument passing
{
	return switch (a)
	{
		case User(id, name) => id,
		case Admin(id, name) => -id,
	};
}

void testImplicitConversion()
{
	assert(accessAccount(Account.Admin(7, "root")) == -7);

	Account a = getAccount();
	assert(accessAccount(a) == 42);
}

// Regression test: bare (non-string) type variants convert implicitly too.
// (`switch` type-pattern matching currently only supports `double`/`string`
// bare-type arms, so `int`/`bool` are verified via `.__tag` and direct
// construction/assignment instead.)
enum union Val
{
	case int,
	case bool,
	case double,
}

Val makeInt() { return 5; }
Val makeBool() { return true; }
Val makeDouble() { return 3.14; }

int classify(Val v)
{
	return switch (v)
	{
		case double d => cast(int) d,
		default => -1,
	};
}

void testBareTypes()
{
	Val vi = 5;
	Val vb = true;
	Val vd = 3.14;
	assert(vi.__tag == 0);
	assert(vb.__tag == 1);
	assert(vd.__tag == 2);

	assert(makeInt().__tag == 0);
	assert(makeBool().__tag == 1);
	assert(makeDouble().__tag == 2);

	assert(classify(3.14) == 3);
	assert(classify(makeDouble()) == 3);
}

alias NullOptionNone = typeof(null);
enum union NullOption(T)
{
	case Some(T),
	case typeof(null),
}

enum union OptionAlias(T)
{
	case Some(T),
	case None,
}

void testNullLikeBareType()
{
	NullOption!int empty = null;
	assert(switch (empty)
	{
		case Some(v) => v,
		case typeof(null) => -1,
	} == -1);

	NullOption!int filled = 42;
	assert(switch (filled)
	{
		case Some(v) => v,
		case typeof(null) => -1,
	} == 42);

	OptionAlias!int empty2 = null;
	assert(switch (empty2)
	{
		case Some(v) => v,
		case None => -1,
	} == -1);

	OptionAlias!int filled2 = 99;
	assert(switch (filled2)
	{
		case Some(v) => v,
		case None => -1,
	} == 99);
}

// Regression test: struct/record variants convert implicitly on
// both argument passing and `return`.
enum union Response2
{
	case double,
	case Success { int code; string payload; }
}

Response2 makeDouble2() { return 3.14; }
Response2 makeSuccess2() { return Response2.Success(200, "OK"); }

string describe2(Response2 r)
{
	return switch (r)
	{
		case double d => "double",
		case Success { code, .. } => "success",
	};
}

void testStructVariant()
{
	assert(describe2(3.14) == "double");
	assert(describe2(Response2.Success(1, "ok")) == "success");
	assert(describe2(makeDouble2()) == "double");
	assert(describe2(makeSuccess2()) == "success");
}

// Regression test: `string` bare-type variants used to be misidentified by
// `switch` pattern matching (matched the wrong arm at runtime) because the
// unresolved `TypeIdentifier` for `string` was compared without running
// `typeSemantic()` on it first. See dcast.d/expressionsem.d fixes.
enum union Response
{
	case double,
	case string,
	case Success { int code; string payload; }
}

Response makeDouble3() { return 3.14; }
Response makeString3() { return "hello"; }
Response makeSuccess3() { return Response.Success(200, "OK"); }

string describe(Response r)
{
	return switch (r)
	{
		case double d => "double",
		case string s => "string",
		case Success { code, .. } => "success",
	};
}

void testHybridResponse()
{
	assert(describe(3.14) == "double");
	assert(describe("hi") == "string");
	assert(describe(Response.Success(1, "ok")) == "success");
	assert(describe(makeDouble3()) == "double");
	assert(describe(makeString3()) == "string");
	assert(describe(makeSuccess3()) == "success");
}

// Regression test: `if` guards on switch expression arms, including
// multiple guarded arms for the same variant, a plain (unguarded) arm for
// the same variant as a guard-fallback, and bindings that are visible to
// both the guard condition and the arm action.
string classifyShape(Shape s)
{
	return switch (s)
	{
		case Circle(r) if (r > 10.0) => "big circle",
		case Circle(r) if (r <= 10.0) => "small circle",
		case Rectangle(w, h) if (w == h) => "square",
		case Rectangle(w, h) => "rectangle",
		case Point => "point",
		default => "unreachable",
	};
}

enum union GuardVal
{
	case double,
	case string,
}

string classifyGuardVal(GuardVal v)
{
	return switch (v)
	{
		case double d if (d > 0.0) => "positive double",
		case double d => "non-positive double",
		case string s => "string",
		default => "unreachable",
	};
}

void testGuards()
{
	assert(classifyShape(Shape.Circle(20.0)) == "big circle");
	assert(classifyShape(Shape.Circle(3.0)) == "small circle");
	assert(classifyShape(Shape.Rectangle(4.0, 4.0)) == "square");
	assert(classifyShape(Shape.Rectangle(4.0, 5.0)) == "rectangle");
	assert(classifyShape(Shape.Point) == "point");

	assert(classifyGuardVal(5.0) == "positive double");
	assert(classifyGuardVal(-5.0) == "non-positive double");
	assert(classifyGuardVal("hi") == "string");
}

// Regression test: enum union variants wrapping "compound" payload types:
// arrays, associative arrays, pointers, void[]/void*, noreturn*/noreturn[],
// function/delegate pointers, char/wchar/dchar, string/wstring/dstring,
// static arrays, and complex/imaginary numerics.
enum union CompoundTypes
{
	case Arr(int[]),
	case AssocArr(int[string]),
	case Ptr(int*),
	case VoidArr(void[]),
	case VoidPtr(void*),
	case NoReturnPtr(noreturn*),
	case NoReturnArr(noreturn[]),
	case FuncPtr(int function(int)),
	case Del(int delegate(int)),
	case Ch(char),
	case WCh(wchar),
	case DCh(dchar),
	case Str(string),
	case WStr(wstring),
	case DStr(dstring),
	case StaticArr(int[4]),
	case Cplx(cdouble),
	case Imag(idouble),
}

private int addOne(int x) { return x + 1; }

void testCompoundTypes()
{
	int local = 42;
	int[string] aa;
	aa["x"] = 1;

	auto arr = CompoundTypes.Arr([1, 2, 3]);
	auto assocArr = CompoundTypes.AssocArr(aa);
	auto ptr = CompoundTypes.Ptr(&local);
	auto voidArr = CompoundTypes.VoidArr(cast(void[])[1, 2, 3]);
	auto voidPtr = CompoundTypes.VoidPtr(cast(void*)&local);
	auto noReturnPtr = CompoundTypes.NoReturnPtr(null);
	auto noReturnArr = CompoundTypes.NoReturnArr([]);
	auto funcPtr = CompoundTypes.FuncPtr(&addOne);
	int delegate(int) dg = (int x) => x * 2;
	auto del = CompoundTypes.Del(dg);
	auto ch = CompoundTypes.Ch('a');
	auto wch = CompoundTypes.WCh('b');
	auto dch = CompoundTypes.DCh('c');
	auto str = CompoundTypes.Str("hello");
	auto wstr = CompoundTypes.WStr("world"w);
	auto dstr = CompoundTypes.DStr("!"d);
	int[4] sa = [1, 2, 3, 4];
	auto staticArr = CompoundTypes.StaticArr(sa);
	auto cplx = CompoundTypes.Cplx(1.0 + 2.0i);
	auto imag = CompoundTypes.Imag(3.0i);

	assert(arr.__tag == 0);
	assert(assocArr.__tag == 1);
	assert(ptr.__tag == 2);
	assert(voidArr.__tag == 3);
	assert(voidPtr.__tag == 4);
	assert(noReturnPtr.__tag == 5);
	assert(noReturnArr.__tag == 6);
	assert(funcPtr.__tag == 7);
	assert(del.__tag == 8);
	assert(ch.__tag == 9);
	assert(wch.__tag == 10);
	assert(dch.__tag == 11);
	assert(str.__tag == 12);
	assert(wstr.__tag == 13);
	assert(dstr.__tag == 14);
	assert(staticArr.__tag == 15);
	assert(cplx.__tag == 16);
	assert(imag.__tag == 17);

	int sum = switch (arr)
	{
		case Arr(a) => a[0] + a[1] + a[2],
		default => -1,
	};
	assert(sum == 6);

	int v = switch (assocArr)
	{
		case AssocArr(a) => a["x"],
		default => -1,
	};
	assert(v == 1);

	int derefed = switch (ptr)
	{
		case Ptr(p) => *p,
		default => -1,
	};
	assert(derefed == 42);

	size_t voidArrLen = switch (voidArr)
	{
		case VoidArr(a) => a.length,
		default => size_t.max,
	};
	assert(voidArrLen == 12); // 3 ints * 4 bytes

	bool voidPtrNonNull = switch (voidPtr)
	{
		case VoidPtr(p) => p !is null,
		default => false,
	};
	assert(voidPtrNonNull);

	int called = switch (funcPtr)
	{
		case FuncPtr(f) => f(9),
		default => -1,
	};
	assert(called == 10);

	int doubled = switch (del)
	{
		case Del(d) => d(9),
		default => -1,
	};
	assert(doubled == 18);

	char c = switch (ch)
	{
		case Ch(x) => x,
		default => '?',
	};
	assert(c == 'a');

	string s = switch (str)
	{
		case Str(x) => x,
		default => "",
	};
	assert(s == "hello");

	int staticArrSum = switch (staticArr)
	{
		case StaticArr(a) => a[0] + a[1] + a[2] + a[3],
		default => -1,
	};
	assert(staticArrSum == 10);
}

// Regression test: enum union variants holding a plain function and
// multiple delegates. Reassigning between variants (and within the same
// variant) with different closures must never leave a stale/mixed-up
// delegate context pointer behind.
enum union Callable
{
	case Fn(int function(int)),
	case Dg(int delegate(int)),
	case Dg2(int delegate(int)),
}

private int call(Callable c)
{
	return switch (c)
	{
		case Fn(f) => f(1),
		case Dg(d) => d(1),
		case Dg2(d) => d(1),
	};
}

private int makeClosureAndCall(int captured)
{
	int delegate(int) dg = (int x) => x + captured;
	return call(Callable.Dg(dg));
}

enum union Handler
{
	case OnClick { int delegate(int) callback; },
	case OnHover { int delegate(int) callback; },
}

private int callHandler(Handler h, int x)
{
	return switch (h)
	{
		case OnClick { callback } => callback(x),
		case OnHover { callback } => callback(x),
	};
}

void testCallables()
{
	Callable cf = Callable.Fn((int x) => x + 1);
	assert(call(cf) == 2);

	// Two delegates capturing DIFFERENT locals: a stale/mixed-up context
	// pointer would silently add the wrong value.
	int a = 100;
	int b = 200;
	int delegate(int) dgA = (int x) => x + a;
	int delegate(int) dgB = (int x) => x + b;

	Callable c1 = Callable.Dg(dgA);
	assert(call(c1) == 101);

	// Reassign the SAME variant tag (Dg -> Dg) with a different closure.
	c1 = Callable.Dg(dgB);
	assert(call(c1) == 201);

	// Reassign to a DIFFERENT variant tag (Dg -> Dg2) with yet another closure.
	int cCap = 300;
	int delegate(int) dgC = (int x) => x + cCap;
	c1 = Callable.Dg2(dgC);
	assert(call(c1) == 301);

	// Reassign back to Dg with dgA: context must be dgA's, not dgC's leftover.
	c1 = Callable.Dg(dgA);
	assert(call(c1) == 101);

	// Each call creates a distinct closure; verifies no cross-contamination.
	assert(makeClosureAndCall(5) == 6);
	assert(makeClosureAndCall(50) == 51);

	// Common delegate field, accessed via switch.
	int clicks, hovers;
	int delegate(int) onClick = (int x) { clicks += x; return clicks; };
	int delegate(int) onHover = (int x) { hovers += x; return hovers; };

	Handler h = Handler.OnClick(onClick);
	assert(callHandler(h, 5) == 5);
	assert(clicks == 5 && hovers == 0);

	h = Handler.OnHover(onHover);
	assert(callHandler(h, 3) == 3);
	assert(hovers == 3 && clicks == 5);

	// Reassign the same variant with a different closure; the switch-based
	// call must use the new context, not the previous one.
	int otherClicks;
	int delegate(int) onClick2 = (int x) { otherClicks += x * 2; return otherClicks; };
	h = Handler.OnClick(onClick2);
	assert(callHandler(h, 4) == 8);
	assert(otherClicks == 8 && clicks == 5);
}

// Regression test: all the compound types tested as NAMED variant payloads
// above also work as bare (unnamed) variant types, including identifier-
// spelled types followed by `*`/`[]` (e.g. `noreturn*`), which previously
// mis-parsed as a named unit variant called e.g. `noreturn`.
enum union BareCompoundTypes
{
	case int[],
	case int[string],
	case int*,
	case void[],
	case void*,
	case noreturn*,
	case noreturn[],
	case int function(int),
	case int delegate(int),
	case char,
	case wchar,
	case dchar,
	case string,
	case wstring,
	case dstring,
	case int[4],
	case cdouble,
	case idouble,
}

void testBareCompoundTypes()
{
	int local = 7;
	int[string] aa;
	aa["y"] = 2;
	int[4] sa = [1, 2, 3, 4];

	BareCompoundTypes v0 = [1, 2, 3];
	BareCompoundTypes v1 = aa;
	BareCompoundTypes v2 = &local;
	BareCompoundTypes v3 = cast(void[])[1, 2, 3];
	BareCompoundTypes v4 = cast(void*)&local;
	BareCompoundTypes v5 = cast(noreturn*) null;
	BareCompoundTypes v6 = cast(noreturn[])[];
	int function(int) plainFn = (int x) => x + 1;
	BareCompoundTypes v7 = plainFn; // non-capturing lambda: ambiguous unless explicitly typed first
	BareCompoundTypes v8 = (int x) => x + local; // captures `local`: unambiguously a delegate
	BareCompoundTypes v9 = 'a';
	BareCompoundTypes v10 = cast(wchar)'b';
	BareCompoundTypes v11 = cast(dchar)'c';
	BareCompoundTypes v12 = "hello";
	BareCompoundTypes v13 = "world"w;
	BareCompoundTypes v14 = "!"d;
	BareCompoundTypes v15 = sa;
	BareCompoundTypes v16 = 1.0 + 2.0i;
	BareCompoundTypes v17 = 3.0i;

	assert(v0.__tag == 0);
	assert(v1.__tag == 1);
	assert(v2.__tag == 2);
	assert(v3.__tag == 3);
	assert(v4.__tag == 4);
	assert(v5.__tag == 5);
	assert(v6.__tag == 6);
	assert(v7.__tag == 7);
	assert(v8.__tag == 8);
	assert(v9.__tag == 9);
	assert(v10.__tag == 10);
	assert(v11.__tag == 11);
	assert(v12.__tag == 12);
	assert(v13.__tag == 13);
	assert(v14.__tag == 14);
	assert(v15.__tag == 15);
	assert(v16.__tag == 16);
	assert(v17.__tag == 17);
}


// Regression test: bare function-pointer and delegate variants with the same
// signature. A lambda's inferred attributes (`pure nothrow @nogc @safe`)
// used to prevent implicit construction entirely, since the enum union
// implicit-conversion check required an exact type match; attribute
// widening is now allowed specifically for callable payload types (it can
// never introduce cross-variant ambiguity the way numeric widening would).
enum union Funs
{
	case int function(int),
	case int delegate(int),
}

void testBareCallables()
{
	// A non-capturing lambda is convertible to *either* a function pointer or
	// a delegate with the same signature, so assigning it directly to `Funs`
	// is genuinely ambiguous and must go through an explicitly-typed
	// intermediate (same as f3/f4 below); a capturing closure, however, can
	// only ever be a delegate, so it unambiguously selects that variant.
	int function(int) plainFn = (int x) => x + 1;
	Funs f1 = plainFn; // decays to a plain function pointer
	int captured = 10;
	Funs f2 = (int x) => x + captured; // closure -> delegate (unambiguous)

	assert(f1.__tag == 0);
	assert(f2.__tag == 1);

	int function(int) fp = (int x) => x + 1;
	int delegate(int) dg = (int x) => x + captured;
	Funs f3 = fp;
	Funs f4 = dg;
	assert(f3.__tag == 0);
	assert(f4.__tag == 1);
}

// Regression test: `enum union` member declarations (functions, static
// functions, manifest constants) after a `;` following the variant list, per
// the grammar's `(";" MemberDeclarationList)?`. Member functions can use
// `switch (this)` to dispatch on the active variant, and named-variant
// factory functions (`Shape.Circle(...)`) still get synthesized correctly
// alongside user-declared members.
enum union ShapeWithMethods
{
	case Circle(double),
	case Rectangle(double, double),
	case Point;

	double area()
	{
		return switch (this)
		{
			case Circle(r) => 3.14159 * r * r,
			case Rectangle(w, h) => w * h,
			case Point => 0.0,
		};
	}

	string describe()
	{
		return switch (this)
		{
			case Circle(r) => "circle",
			case Rectangle(w, h) => "rectangle",
			case Point => "point",
		};
	}

	static ShapeWithMethods unit() { return ShapeWithMethods.Point; }

	enum string kind = "shape";
}

void testMemberFunctions()
{
	ShapeWithMethods c = ShapeWithMethods.Circle(2.0);
	assert(c.describe() == "circle");
	assert(c.area() > 12.5 && c.area() < 12.6);

	ShapeWithMethods r = ShapeWithMethods.Rectangle(3.0, 4.0);
	assert(r.describe() == "rectangle");
	assert(r.area() == 12.0);

	ShapeWithMethods u = ShapeWithMethods.unit();
	assert(u.describe() == "point");
	assert(u.area() == 0.0);

	assert(ShapeWithMethods.kind == "shape");
}

// Regression test: exhaustiveness checking. A `switch` covering every
// variant (unguarded) needs no `default` and compiles/runs fine; combining
// a guarded arm, an unguarded fallback for the same variant, and a
// `default` for the rest is exhaustive and non-redundant.
enum union Traffic
{
	case Red,
	case Yellow,
	case Green,
}

string classifyTraffic(Traffic t)
{
	return switch (t)
	{
		case Red => "stop",
		case Yellow => "caution",
		case Green => "go",
	};
}

enum union Level
{
	case double,
	case string,
}

string classifyLevel(Level v)
{
	return switch (v)
	{
		case double d if (d > 100.0) => "high",
		case double d => "normal",
		default => "other",
	};
}

void testExhaustiveness()
{
	assert(classifyTraffic(Traffic.Red) == "stop");
	assert(classifyTraffic(Traffic.Yellow) == "caution");
	assert(classifyTraffic(Traffic.Green) == "go");

	assert(classifyLevel(150.0) == "high");
	assert(classifyLevel(50.0) == "normal");
	assert(classifyLevel("hi") == "other");
}

int lifecycleCopyCount;

struct CopyablePayload
{
	int x;
	this(ref CopyablePayload other)
	{
		lifecycleCopyCount++;
		x = other.x;
	}
}

enum union WithCopyable
{
	case Wrapped(CopyablePayload),
	case Flag(bool),
}

void testLifecycleCopyableVariant()
{
	lifecycleCopyCount = 0;
	WithCopyable a = WithCopyable.Wrapped(CopyablePayload(7));
	WithCopyable b = a;
	assert(lifecycleCopyCount == 1);
	assert(a.__tag == 0);
	assert(b.__tag == 0);
}
