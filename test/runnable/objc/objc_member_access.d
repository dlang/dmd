// PLATFORM: osx
// EXTRA_OBJC_SOURCES: objc_member_access.m
// REQUIRED_ARGS: -L-framework -LCocoa

import std.c.stdio;

extern (Objective-C)
class NSObject {
	void* isa;
	
	static NSObject alloc() [alloc];
	NSObject init() [init];
}

int globalVar;

class TestObject : NSObject {
	int memberVar;
	
	void test() {
		assert(memberVar == 0);
		memberVar = 2;
		globalVar = 4;
	}
}

void testMemberAccess ()
{
	TestObject o = cast(TestObject)cast(void*)TestObject.alloc().init();
	o.test();
	assert(o.memberVar == 2);
	assert(globalVar == 4);
}

version (D_ObjCNonFragileABI)
{
	extern (Objective-C)
	class NonFragileBase : NSObject
	{
		// We're deliberately not including this field to test non-fragile fields.
		// Objective-C doesn't require to declare fields in the @interface declaration when
		// using the non-fragile ABI.
		// size_t _a;

		@property size_t a();
		@property void a(size_t value);
	}

	class NonFragile : NonFragileBase
	{
		size_t b;
	}

	void testNonFragileFields ()
	{
		auto o = new NonFragile;

		assert(o.a == 0);
		assert(o.b == 0);

		o.a = 3;
		o.b = 5;
		assert(o.a == 3);
		assert(o.b == 5);

		o.a = 4;
		o.b = 8;
		assert(o.a == 4);
		assert(o.b == 8);

		o.a = 10;
		auto ptr = &o.b;
		*ptr = 14;
		assert(o.a == 10);
		assert(o.b == 14);
	}
}

void main()
{
	testMemberAccess();

	version (D_ObjCNonFragileABI)
		testNonFragileFields();
}