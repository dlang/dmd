// https://github.com/dlang/dmd/issues/22671
// GC allocations inside `if (__ctfe)` blocks should be allowed in @nogc functions

class Foo {}

// Test 1: new class in @nogc function returning via if (__ctfe)
@nogc Foo bar()
{
    if (__ctfe)
    {
        return new Foo();  // allowed - only runs at compile time
    }
    return null;
}

// Test 2: new array in @nogc void function
@nogc void test_array()
{
    if (__ctfe)
    {
        int[] a = new int[](10);  // allowed
    }
}

// Test 3: if (__ctfe) with else branch
@nogc int test_with_else()
{
    if (__ctfe)
    {
        int[] a = new int[](5);  // allowed
        return a[0];
    }
    else
    {
        return 0;
    }
}

// Test 4: rewritten `if (!__ctfe)` (compiler rewrites to `if (__ctfe)` internally)
@nogc int test_not_ctfe()
{
    if (!__ctfe)
    {
        return 0;
    }
    else
    {
        int[] a = new int[](3);  // allowed - this is the ctfe branch
        return cast(int) a.length;
    }
}
