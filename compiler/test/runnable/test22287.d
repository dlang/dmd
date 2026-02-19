/*
TEST_OUTPUT:
---
---
*/

/**
 * Regression test for UDA handling refactoring.
 * Covers single attributes, tuple attributes, and recursive collection.
 * https://github.com/dlang/dmd/pull/22287
 */
module test22287;

struct MyUda {}
struct AnotherUda { int x; }

// 1. Single attribute (tests the new 'else' branch in foreachUda)
@MyUda void testSingle() {}

// 2. Multiple attributes in a tuple (tests TupleExp handling)
@(MyUda, AnotherUda(42)) void testMultiple() {}

// 3. Nested attributes (tests recursive collection in getAttributes)
@MyUda
{
    @AnotherUda(100) int testNested;
}

void main()
{
    // Check single attribute
    alias attrs1 = __traits(getAttributes, testSingle);
    static assert(attrs1.length == 1);
    static assert(is(attrs1[0] == MyUda));

    // Check multiple attributes
    alias attrs2 = __traits(getAttributes, testMultiple);
    static assert(attrs2.length == 2);
    static assert(is(attrs2[0] == MyUda));
    static assert(attrs2[1].x == 42);

    // Check nested attributes collection
    alias attrs3 = __traits(getAttributes, testNested);
    static assert(attrs3.length == 2);
    static assert(is(attrs3[0] == MyUda));
    static assert(attrs3[1].x == 100);

    // Verify main itself (standalone check)
    alias attrsMain = __traits(getAttributes, main);
    static assert(attrsMain.length == 0);
}
