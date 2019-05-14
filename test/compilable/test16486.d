// Example 1 - Simple case
struct TestType(T, Q) { }
alias TestAlias(T, Q) = TestType!(T, Q);
static void testFunction(T, Q)(TestAlias!(T, Q) arg) { }

// Example 2 - Real-world case, an initial motivation
// for the fix is Mir users to be able to do such aliasing.
struct Slice(T) {
}

struct StairsIterator(T, string direction) {
}

alias PackedUpperTriangularMatrix(T) = Slice!(StairsIterator!(T*, "-"));

auto foo(T)(PackedUpperTriangularMatrix!T m)
{
}

// Example 3 - Multiple levels of aliasing
struct TestType2(T) {}
struct EnclosingType(T) {}
alias TestAlias2(T) = TestType2!(EnclosingType!T);
void testFunction2(T)(TestAlias2!(T) arg) {}

// Example 4 - Mismatch of root argument names and final argument names
struct TestType3(A, B) { }
alias TestAlias3(A, B) = TestType3!(A, B);
alias TestAlias4(T, Q) = TestAlias3!(T, Q);
void testFunction3(T, Q)(TestAlias4!(T, Q) arg) {}

// Example 5 - More complicated mismatch of argument names
struct TestType5(T, Q) { }
template TestAlias5(T, Q)
{
    alias A = T;
    alias TestAlias5 = TestType5!(A, Q);
}
alias TestAlias6(T, Q) = TestAlias5!(T, Q);
void testFunction4(T, Q)(TestAlias6!(T, Q) arg) {}

void main()
{
	// Example 1
    TestAlias!(int, float) testObj;
    testFunction(testObj);

	// Example 2
    PackedUpperTriangularMatrix!(int) m;
    foo(m);

	// Example 3
    TestAlias2!(int) testObj2;
    testFunction2(testObj2);
	
	// Exmaple 4
	TestAlias4!(int, float) testObj3;
	testFunction3(testObj3);
	
	// Example 5
	TestAlias6!(int, float) testObj4;
	testFunction4(testObj4);
}
