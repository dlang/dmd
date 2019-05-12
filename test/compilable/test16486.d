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

void main()
{
    TestAlias!(int, float) testObj;
    testFunction(testObj);

    PackedUpperTriangularMatrix!(int) m;
    foo(m);

    TestAlias2!(int) testObj2;
    testFunction2(testObj2);
}
